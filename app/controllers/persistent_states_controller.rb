class PersistentStatesController < ApplicationController
  def update
    session[params[:key].to_sym] = params[:value]
    head :ok
  end
end
