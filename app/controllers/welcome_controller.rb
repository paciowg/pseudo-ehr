# app/controllers/welcome_controller.rb
class WelcomeController < ApplicationController
  def index
    return unless server_present?

    flash[:notice] = I18n.t('controllers.welcome.connected_to_server', server_url: @current_server.base_url)
    redirect_to patients_path
  end
end
