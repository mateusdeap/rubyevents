class EventsController < ApplicationController
  include WatchedTalks
  include Pagy::Backend
  skip_before_action :authenticate_user!, only: %i[index show update]
  before_action :set_event, only: %i[show edit update]
  before_action :set_user_favorites, only: %i[show]

  # GET /events
  def index
    @events = Event.canonical.includes(:organisation).order("events.name ASC")
    @events = @events.where("lower(events.name) LIKE ?", "#{params[:letter].downcase}%") if params[:letter].present?
    @events = @events.ft_search(params[:s]) if params[:s].present?
  end

  # GET /events/1
  def show
    set_meta_tags(@event)

    event_talks = if @event.organisation.meetup?
      @event.talks_in_running_order.where(meta_talk: true).or(
        @event.talks_in_running_order.where.not(video_provider: "parent")
      ).order(date: :desc)
    else
      @event.talks_in_running_order.order(date: :asc)
    end

    event_talks = event_talks.includes(:speakers, :parent_talk, child_talks: :speakers)

    if params[:q].present?
      talks = event_talks.pagy_search(params[:q])
      @pagy, @talks = pagy_meilisearch(talks, limit: 21)
    else
      @pagy, @talks = pagy(event_talks, limit: 21)
    end
  end

  # GET /events/1/edit
  def edit
  end

  # PATCH/PUT /events/1
  def update
    suggestion = @event.create_suggestion_from(params: event_params, user: Current.user)

    if suggestion.persisted?
      redirect_to event_path(@event), notice: suggestion.notice
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_event
    @event = Event.includes(:organisation).find_by!(slug: params[:slug])
    redirect_to event_path(@event.canonical), status: :moved_permanently if @event.canonical.present?
  end

  # Only allow a list of trusted parameters through.
  def event_params
    params.require(:event).permit(:name, :city, :country_code)
  end

  def set_user_favorites
    return unless Current.user

    @user_favorite_talks_ids = Current.user.default_watch_list.talks.ids
  end
end
