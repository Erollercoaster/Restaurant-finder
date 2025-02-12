class RestaurantsController < ApplicationController
  before_action :authenticate_user!, except: [:search]
  before_action :set_restaurant, only: [:show]

  def search
    unless user_signed_in?
      render json: { error: "You must be logged in to perform a search." }, status: :unauthorized
      return
    end
    Rails.logger.debug "=== Starting Restaurant Search ==="
    
    address = params[:address]
    radius = params[:radius] || 1000
    max_results = params[:max_results] || 20
    cuisine = params[:cuisine]
    sort_by = params[:sort_by]
    show_favorites = params[:show_favorites] == 'true'
  
    Rails.logger.debug "Search params: address=#{address}, radius=#{radius}, max_results=#{max_results}, cuisine=#{cuisine}, sort_by=#{sort_by}, show_favorites=#{show_favorites}"
  
    if address.blank?
      flash.now[:alert] = "Address is required for the search."
      return render :search
    end
  
    places_service = GooglePlacesService.new
  
    # Step 1: Geocode the address
    location = places_service.geocode_address(address)
    Rails.logger.debug "Geocoded location: #{location.inspect}"
  
    if location[:error]
      flash.now[:alert] = "Unable to find the specified address. Please try again."
      return render :search
    end
  
    # Step 2: Search restaurants using lat/lng from geocoding
    lat = location[:latitude]
    lng = location[:longitude]
  
    begin
      restaurant_attrs_list = places_service.search_restaurants(
        lat,
        lng,
        radius.to_f,
        max_results.to_i
      )
  
      Rails.logger.debug "Received #{restaurant_attrs_list.length} restaurants"
  
      if restaurant_attrs_list.any?
        restaurants = restaurant_attrs_list.map do |attrs|
          restaurant = Restaurant.find_or_initialize_by(place_id: attrs[:place_id])
          attrs[:cuisine] = normalize_cuisine(attrs[:cuisine])
          Rails.logger.debug "Restaurant attributes: #{attrs.inspect}"
          restaurant.assign_attributes(attrs)
          if restaurant.new_record? || restaurant.changed?
            restaurant.save
            Rails.logger.debug "Saved restaurant: #{restaurant.attributes.inspect}"
          else
            Rails.logger.debug "Restaurant unchanged: #{restaurant.attributes.inspect}"
          end
          restaurant
        end
  
        # Apply filters
        restaurants = filter_restaurants(restaurants, cuisine, sort_by, show_favorites)
  
        # Convert to array of hashes with favorite status
        @restaurants = restaurants.map do |restaurant|
          restaurant_hash = restaurant.as_json(
            methods: [:average_rating],
            only: [:id, :name, :address, :latitude, :longitude, :price_level, :cuisine, :photo_url, :place_id]
          )
          restaurant_hash['is_favorite'] = user_signed_in? ? current_user.favorites.exists?(restaurant_id: restaurant.id) : false
          restaurant_hash['reviews_count'] = restaurant.reviews.count
          restaurant_hash
        end

        flash.now[:notice] = "Found #{@restaurants.count} restaurants matching your criteria."
      else
        flash.now[:notice] = "No restaurants found for the specified location and criteria."
        @restaurants = []
      end
    rescue StandardError => e
      Rails.logger.error("Restaurant Search Error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      flash.now[:alert] = "An error occurred while searching for restaurants. Please try again later."
      @restaurants = []
    end
  
    respond_to do |format|
      format.html
      format.json { render json: @restaurants }
    end
  end
  
  def show
    @reviews = @restaurant.reviews.includes(:user).order(created_at: :desc)
    @average_rating = @restaurant.average_rating
    @user_review = @restaurant.reviews.find_by(user: current_user) if user_signed_in?
    @review = Review.new
    @is_favorite = user_signed_in? && current_user.favorites.exists?(restaurant: @restaurant)

    respond_to do |format|
      format.html
      format.json { 
        render json: @restaurant.as_json(
          methods: [:average_rating, :reviews_count],
          only: [:id, :name, :address, :latitude, :longitude, :price_level, :cuisine, :photo_url, :place_id]
        ).merge(is_favorite: @is_favorite)
      }
    end
  end

  private

  def filter_restaurants(restaurants, cuisine, sort_by, show_favorites)
    # Filter by cuisine
    if cuisine.present?
      restaurants = restaurants.select { |r| r.cuisine&.downcase&.include?(cuisine.downcase) }
    end

    # Filter favorites
    if show_favorites && current_user
      restaurant_ids = current_user.favorites.pluck(:restaurant_id)
      restaurants = restaurants.select { |r| restaurant_ids.include?(r.id) }
    end

    # Sort restaurants
    case sort_by
    when 'rating'
      restaurants = restaurants.sort_by { |r| -r.average_rating }
    when 'reviews'
      restaurants = restaurants.sort_by { |r| -r.reviews.count }
    when 'price_asc'
      price_order = ['Free', 'Inexpensive', 'Moderate', 'Expensive', 'Very Expensive', 'Unknown']
      restaurants = restaurants.sort_by { |r| price_order.index(r.price_level) || -1 }
    when 'price_desc'
      price_order = ['Very Expensive', 'Expensive', 'Moderate', 'Inexpensive', 'Free', 'Unknown']
      restaurants = restaurants.sort_by { |r| price_order.index(r.price_level) || -1 }
    end

    restaurants
  end

  def normalize_cuisine(cuisine)
    return nil if cuisine.blank?

    normalized = cuisine.downcase
      .gsub('_restaurant', '')
      .gsub('_food', '')
      .gsub('_house', '')
      .split(',')
      .map(&:strip)
      .reject { |c| c == 'restaurant' } # Remove standalone 'restaurant'
      .uniq
      .join(', ')

    normalized.presence
  end

  def set_restaurant
    @restaurant = Restaurant.find(params[:id])
  end
end

