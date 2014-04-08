module Verify
  class TwoFactorsController < ApplicationController
    before_action :timeout_temp_user_in_session

    def new
      two_factor = TwoFactor.find_or_create_by(member_id: temp_user.id)

      # false below will be replaced by user settings like current_user.enable_login_two_factor?
      if false && two_factor.activated?
        @two_factor = TwoFactor.new
      else
        auth_success and return
      end
    end

    def create
      two_factor = temp_user.two_factor
      two_factor.assign_attributes(two_factor_params)

      if two_factor.verify
        auth_success
      else
        redirect_to new_verify_two_factor_path, alert: t('.error')
      end
    end

    private

    def two_factor_params
      params.require(:two_factor).permit(:otp)
    end

    def timeout_temp_user_in_session
      redirect_to signin_path, notice: t('.timeout') if temp_user.nil?
    end

    def auth_success
      member_id = session[:temp_member_id]
      reset_session
      session[:member_id] = member_id
      send_signin_notification
      redirect_to settings_path
    end

    def send_signin_notification
      # false below will be placed by a method that return true if user sign in at different ip
      if false && current_user.activated?
        MemberMailer.notify_signin(member_id).deliver
      end
    end

    def temp_user
      @temp_user ||= Member.find_by_id(session[:temp_member_id])
    end
  end
end
