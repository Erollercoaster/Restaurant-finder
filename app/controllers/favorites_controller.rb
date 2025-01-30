class FavoritesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_restaurant

  def toggle
    favorite = current_user.favorites.find_or_initialize_by(restaurant: @restaurant)

    begin
      ActiveRecord::Base.transaction do
        if favorite.persisted?
          favorite.destroy
          flash[:notice] = "Restaurant removed from favorites."
        else
          favorite.save!
          flash[:notice] = "Restaurant added to favorites."
        end
      end

      respond_to do |format|
        format.html { redirect_to @restaurant }
        format.json { render json: { status: favorite.persisted? ? 'favorited' : 'unfavorited', is_favorite: favorite.persisted? } }
      end
    rescue ActiveRecord::RecordInvalid => e
      flash[:alert] = "Unable to update favorites: #{e.message}"
      respond_to do |format|
        format.html { redirect_to @restaurant }
        format.json { render json: { error: e.message }, status: :unprocessable_entity }
      end
    rescue StandardError => e
      flash[:alert] = "An unexpected error occurred while updating favorites."
      respond_to do |format|
        format.html { redirect_to @restaurant }
        format.json { render json: { error: 'An unexpected error occurred' }, status: :internal_server_error }
      end
    end
  end

  private

  def set_restaurant
    @restaurant = Restaurant.find(params[:restaurant_id])
  end
end

