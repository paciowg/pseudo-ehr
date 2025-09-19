class PersistentStatesController < ApplicationController
  def update_drawer
    session_key = params[:session_key]&.to_sym
    visible = params[:visible]

    if session_key && [true, false].include?(visible)
      session[session_key] = visible
      head :ok
    else
      head :bad_request
    end
  end
end
