module Api
  module V1
    class BookmarksController < ApplicationController
      before_action :ensure_attendee!, only: [:create, :destroy, :index]

      def index
        bookmarks = current_user.bookmarks.includes(event: :user).order(created_at: :desc)

        render json: bookmarks.map { |bookmark|
          {
            id: bookmark.id,
            event: {
              id: bookmark.event.id,
              title: bookmark.event.title,
              venue: bookmark.event.venue,
              city: bookmark.event.city,
              starts_at: bookmark.event.starts_at,
              ends_at: bookmark.event.ends_at,
              category: bookmark.event.category,
              organizer: bookmark.event.user.name
            },
            created_at: bookmark.created_at
          }
        }
      end

      def create
        bookmark = current_user.bookmarks.build(event: event)

        if bookmark.save
          render json: {
            id: bookmark.id,
            event_id: bookmark.event_id,
            bookmark_count: bookmark.event.bookmarks.count
          }, status: :created
        else
          render json: { errors: bookmark.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        bookmark = current_user.bookmarks.find_by!(event: event)
        bookmark.destroy
        head :no_content
      end

      private

      def event
        @event ||= Event.find(params[:event_id])
      end

      def ensure_attendee!
        return if current_user.attendee?

        render_forbidden("Only attendees can manage bookmarks")
      end
    end
  end
end
