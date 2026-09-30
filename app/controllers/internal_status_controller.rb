# frozen_string_literal: true

class InternalStatusController < ApplicationController
  before_action :require_admin

  # Checks a user in the directory and refreshes the internal status
  def check
    @user = User.find(params[:id])
    begin
      @result = InternalUserStatus.check!(@user)
    rescue RedmineInternalUsers::DirectoryError => e
      @error = e.message
    end
    respond_to { |format| format.js }
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
