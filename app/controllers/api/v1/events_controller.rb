module Api
  module V1
    class EventsController < ApplicationController
      skip_before_action :authenticate_user!, only: [:index, :show]
      before_action :authenticate_optional_user!, only: [:index, :show]
      before_action :set_event, only: [:show, :update, :destroy]
      before_action :authorize_event_owner!, only: [:update, :destroy]

      def index
        events = Event.published.upcoming

        if params[:search].present?
          query = "%#{ActiveRecord::Base.sanitize_sql_like(params[:search])}%"
          events = events.where("title ILIKE :query OR description ILIKE :query", query: query)
        end

        if params[:category].present?
          events = events.where(category: params[:category])
        end

        if params[:city].present?
          events = events.where(city: params[:city])
        end

        events = events.reorder(sort_clause)

        render json: events.map { |event|
          event_payload = {
            id: event.id,
            title: event.title,
            description: event.description,
            venue: event.venue,
            city: event.city,
            starts_at: event.starts_at,
            ends_at: event.ends_at,
            category: event.category,
            organizer: event.user.name,
            total_tickets: event.total_tickets,
            tickets_sold: event.total_sold,
            ticket_tiers: event.ticket_tiers.map { |t|
              {
                id: t.id,
                name: t.name,
                price: t.price.to_f,
                available: t.available_quantity
              }
            }
          }

          count = bookmark_count_for(event)
          event_payload[:bookmark_count] = count unless count.nil?
          event_payload
        }
      end

      def show
        payload = {
          id: @event.id,
          title: @event.title,
          description: @event.description,
          venue: @event.venue,
          city: @event.city,
          starts_at: @event.starts_at,
          ends_at: @event.ends_at,
          status: @event.status,
          category: @event.category,
          organizer: {
            id: @event.user.id,
            name: @event.user.name
          },
          ticket_tiers: @event.ticket_tiers.map { |t|
            {
              id: t.id,
              name: t.name,
              price: t.price.to_f,
              quantity: t.quantity,
              sold: t.sold_count,
              available: t.available_quantity
            }
          }
        }

        count = bookmark_count_for(@event)
        payload[:bookmark_count] = count unless count.nil?

        render json: payload
      end

      def create
        event = Event.new(event_params)
        event.user = current_user

        if event.save
          render json: event, status: :created
        else
          render json: { errors: event.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @event.update(event_params)
          render json: @event
        else
          render json: { errors: @event.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @event.destroy
        head :no_content
      end

      private

      def set_event
        @event = Event.find(params[:id])
      end

      def authorize_event_owner!
        return if current_user == @event.user || current_user.admin?

        render_forbidden("You are not allowed to modify this event")
      end

      def sort_clause
        allowed_sorts = {
          "starts_at_asc" => { starts_at: :asc },
          "starts_at_desc" => { starts_at: :desc },
          "created_at_desc" => { created_at: :desc }
        }

        allowed_sorts.fetch(params[:sort_by], { starts_at: :asc })
      end

      def bookmark_count_for(event)
        return unless current_user&.organizer? && current_user == event.user

        event.bookmarks.count
      end

      def event_params
        params.require(:event).permit(:title, :description, :venue, :city,
          :starts_at, :ends_at, :category, :max_capacity, :status)
      end
    end
  end
end
