class ReviewsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_restaurant
  before_action :set_review, only: [:edit, :update, :destroy]

  def create
    @review = @restaurant.reviews.build(review_params)
    @review.user = current_user

    if @review.save
      @restaurant.update_ratings_data
      flash[:notice] = "Your review has been successfully posted."
      redirect_to @restaurant
    else
      flash.now[:alert] = "There was an error posting your review: #{@review.errors.full_messages.to_sentence}"
      @reviews = @restaurant.reviews.includes(:user).order(created_at: :desc)
      render 'restaurants/show'
    end
  end

  def edit
    @reviews = @restaurant.reviews.includes(:user).order(created_at: :desc)
    render 'restaurants/show'
  end

  def update
    if @review.update(review_params)
      @restaurant.update_ratings_data
      flash[:notice] = "Your review has been successfully updated."
      redirect_to @restaurant
    else
      flash.now[:alert] = "There was an error updating your review: #{@review.errors.full_messages.to_sentence}"
      @reviews = @restaurant.reviews.includes(:user).order(created_at: :desc)
      render 'restaurants/show'
    end
  end

  def destroy
    @review.destroy
    @restaurant.update_ratings_data
    flash[:notice] = "Your review has been successfully deleted."
    redirect_to @restaurant
  end

  private

  def set_restaurant
    @restaurant = Restaurant.find(params[:restaurant_id])
  end

  def set_review
    @review = current_user.reviews.find(params[:id])
  end

  def review_params
    params.require(:review).permit(:rating, :comment)
  end
end

