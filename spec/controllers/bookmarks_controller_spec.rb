require "rails_helper"

RSpec.describe Api::V1::BookmarksController, type: :request do
  let(:organizer) { create(:user, :organizer) }
  let(:attendee) { create(:user) }
  let(:other_attendee) { create(:user) }
  let(:event) { create(:event, user: organizer, status: "published") }

  def auth_headers(user)
    token = user.generate_jwt
    { "Authorization" => "Bearer #{token}" }
  end

  describe "GET /api/v1/bookmarks" do
    it "returns only the current attendee's bookmarks" do
      own_bookmark = create(:bookmark, user: attendee, event: event)
      other_event = create(:event, user: organizer, status: "published")
      create(:bookmark, user: other_attendee, event: other_event)

      get "/api/v1/bookmarks", headers: auth_headers(attendee)

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)

      expect(data.pluck("id")).to eq([own_bookmark.id])
      expect(data.first.fetch("event")).to include(
        "id" => event.id,
        "title" => event.title
      )
    end

    it "forbids organizers from listing bookmarks" do
      get "/api/v1/bookmarks", headers: auth_headers(organizer)

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)).to eq("error" => "Forbidden")
    end
  end

  describe "POST /api/v1/events/:event_id/bookmark" do
    it "allows an attendee to bookmark an event" do
      expect {
        post "/api/v1/events/#{event.id}/bookmark", headers: auth_headers(attendee)
      }.to change(Bookmark, :count).by(1)

      expect(response).to have_http_status(:created)
      data = JSON.parse(response.body)
      expect(data.fetch("event")).to include(
        "id" => event.id,
        "title" => event.title
      )
    end

    it "rejects duplicate bookmarks for the same attendee and event" do
      create(:bookmark, user: attendee, event: event)

      expect {
        post "/api/v1/events/#{event.id}/bookmark", headers: auth_headers(attendee)
      }.not_to change(Bookmark, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body).fetch("errors")).to include("Event has already been taken")
    end

    it "forbids organizers from bookmarking events" do
      expect {
        post "/api/v1/events/#{event.id}/bookmark", headers: auth_headers(organizer)
      }.not_to change(Bookmark, :count)

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)).to eq("error" => "Forbidden")
    end

    it "returns not found when the event does not exist" do
      post "/api/v1/events/999999/bookmark", headers: auth_headers(attendee)

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)).to eq("error" => "Event not found")
    end
  end

  describe "DELETE /api/v1/events/:event_id/bookmark" do
    it "removes the attendee's bookmark" do
      create(:bookmark, user: attendee, event: event)

      expect {
        delete "/api/v1/events/#{event.id}/bookmark", headers: auth_headers(attendee)
      }.to change(Bookmark, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "is idempotent when the bookmark does not exist" do
      expect {
        delete "/api/v1/events/#{event.id}/bookmark", headers: auth_headers(attendee)
      }.not_to change(Bookmark, :count)

      expect(response).to have_http_status(:no_content)
    end

    it "does not remove another attendee's bookmark" do
      create(:bookmark, user: other_attendee, event: event)

      expect {
        delete "/api/v1/events/#{event.id}/bookmark", headers: auth_headers(attendee)
      }.not_to change(Bookmark, :count)

      expect(response).to have_http_status(:no_content)
      expect(Bookmark.exists?(user: other_attendee, event: event)).to be(true)
    end

    it "forbids organizers from removing bookmarks" do
      create(:bookmark, user: attendee, event: event)

      expect {
        delete "/api/v1/events/#{event.id}/bookmark", headers: auth_headers(organizer)
      }.not_to change(Bookmark, :count)

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)).to eq("error" => "Forbidden")
    end
  end
end
