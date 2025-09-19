class PersistentStatesController < ApplicationController
  def update_drawer
    visible = params[:visible]

    if [true, false].include?(visible)
      session[:queries_visible] = visible
      head :ok
    else
      head :bad_request
    end
  end
end
