require 'digest/md5'

class Gateway::DotpayPlController < Spree::BaseController
  skip_before_filter :verify_authenticity_token, :only => [:comeback, :complete]

  # Show form Dotpay for pay
  def show
    @order = Spree::Order.find(params[:order_id])
    @gateway = @order.available_payment_methods.find{|x| x.id == params[:gateway_id].to_i }
    @order.payments.destroy_all
    payment = @order.payments.create!(:amount => 0, :payment_method_id => @gateway.id)

    if @order.blank? || @gateway.blank?
      flash[:error] = I18n.t("invalid_arguments")
      redirect_to :back
    else
      @bill_address, @ship_address = @order.bill_address, (@order.ship_address || @order.bill_address)
    end
    @channel = session[:dotpay_channel]
    render(:layout => false)
  end

  # redirecting from dotpay.pl
  def complete
    @order = Spree::Order.find(session[:order_id])
    session[:order_id] = nil
     @order.update_attributes({:state => "complete", :completed_at => Time.now}, :without_protection => true)
    redirect_to order_url(@order, {:checkout_complete => true, :order_token => @order.token}), :notice => "Dotpay correct"
  end

  # Result from Dotpay
  def comeback
    @order = Spree::Order.find_by_number(params[:control])
    @gateway = @order && @order.payments.first.payment_method

    if dotpay_pl_validate(@gateway, params, request.remote_ip)
      if params[:t_status]=="2" # dotpay state for payment confirmed
        dotpay_pl_payment_success(params, @order)
      elsif params[:t_status] == "4" or params[:t_status] == "5" #dotpay states for cancellation and so on
        dotpay_pl_payment_cancel(params, @order)
      elsif params[:t_status] == "1"  #dotpay state for starting payment processing (1)
        dotpay_pl_payment_new(params, @order)
      end
      render :text => "OK"
    else
      render :text => "NOT VALID"
    end
  end


  private

  # validating dotpay message
  def dotpay_pl_validate(gateway, params, remote_ip)

    param_args =  (gateway.preferred_urlc_pin.nil? ? "" : gateway.preferred_urlc_pin) + ":" +
      (params[:id].nil? ? "" : params[:id]) + ":" +
      (params[:control].nil? ? "" : params[:control]) + ":" +
      (params[:t_id].nil? ? "" : params[:t_id]) + ":" +
      (params[:amount].nil? ? "" : params[:amount]) + ":" +
      (params[:email].nil? ? "" : params[:email]) + ":::::" +
      (params[:t_status].nil? ? "" : params[:t_status])

    calc_md5 = Digest::MD5.hexdigest(param_args)

      md5_valid = (calc_md5 == params[:md5])

      if md5_valid
        valid = true #yes, it is
      else
       valid = false #no, it isn't
      end
      valid
  end

  # Completed payment process
  def dotpay_pl_payment_success(params, order)
    order.payments.first.started_processing!
    if order.total.to_f == params[:amount].to_f
      order.payments.first.amount = params[:amount].to_f
      order.payments.first.complete
    end

    order.finalize!
    order.payment_state = 'paid'
    order.next
    order.next
    order.save
  end

  # payment cancelled by user (dotpay signals 3 to 5)
  def dotpay_pl_payment_cancel(params, order)
    order.cancel
  end

  def dotpay_pl_payment_new(params, order)
    order.payments.first.started_processing!
    order.finalize!
  end

end


