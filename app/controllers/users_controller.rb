class UsersController < ApplicationController
  load_and_authorize_resource

  def show
    @user_courses = @user.user_courses.page params[:page]
  end

  def edit
  end

  def update
    if @user.update_attributes user_params
      flash[:success] = t "controller.common_flash.update_success",
        object_name: User.name
      redirect_to @user
    else
      render :edit
    end
  end

  private
  def user_params
    if params[:user][:password].blank? && params[:user][:password_confirmation].blank?
      params[:user].delete :password
      params[:user].delete :password_confirmation
    end
    params.require(:user).permit :name, :email, :password, :password_confirmation,
      :avatar
  end
end
