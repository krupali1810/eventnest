module Api
  module V1
    class BookmarksController < ApplicationController
      before_action :require_attendee!

      def index
        bookmarks = current_user.bookmarks.includes(:event).order(created_at: :desc)

        render json: bookmarks.map { |bookmark| serialize_bookmark(bookmark) }
      end

      def create
        event = Event.find(params[:event_id])
        bookmark = current_user.bookmarks.build(event: event)

        if bookmark.save
          render json: serialize_bookmark(bookmark), status: :created
        else
          render json: { errors: bookmark.errors.full_messages }, status: :unprocessable_content
        end
      end

      def destroy
        bookmark = current_user.bookmarks.find_by(event_id: params[:event_id])
        bookmark&.destroy

        head :no_content
      end

      private

      def require_attendee!
        return if current_user.attendee?

        render json: { error: "Forbidden" }, status: :forbidden
      end

      def serialize_bookmark(bookmark)
        {
          id: bookmark.id,
          created_at: bookmark.created_at,
          event: {
            id: bookmark.event.id,
            title: bookmark.event.title,
            starts_at: bookmark.event.starts_at,
            city: bookmark.event.city,
            status: bookmark.event.status
          }
        }
      end
    end
  end
end
