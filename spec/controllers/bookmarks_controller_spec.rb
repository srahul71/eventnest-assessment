require "rails_helper"

RSpec.describe Api::V1::BookmarksController, type: :request do
  let(:organizer) { create(:user, :organizer) }
  let(:attendee) { create(:user) }
  let(:event) { create(:event, user: organizer, status: "published", starts_at: 2.weeks.from_now, ends_at: 2.weeks.from_now + 3.hours) }

  def auth_headers(user)
    token = user.generate_jwt
    { "Authorization" => "Bearer #{token}" }
  end

  describe "POST /api/v1/events/:event_id/bookmark" do
    it "creates a bookmark for an attendee" do
      post "/api/v1/events/#{event.id}/bookmark", headers: auth_headers(attendee)

      expect(response).to have_http_status(:created)
      expect(attendee.bookmarks.count).to eq(1)
      expect(JSON.parse(response.body)).to include(
        "event_id" => event.id,
        "bookmark_count" => 1
      )
    end

    it "rejects duplicate bookmarks" do
      create(:bookmark, user: attendee, event: event)

      post "/api/v1/events/#{event.id}/bookmark", headers: auth_headers(attendee)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["errors"]).to include("Event has already been taken")
    end

    it "rejects organizers" do
      post "/api/v1/events/#{event.id}/bookmark", headers: auth_headers(organizer)

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)).to eq("error" => "Only attendees can manage bookmarks")
    end
  end

  describe "DELETE /api/v1/events/:event_id/bookmark" do
    it "removes the attendee bookmark" do
      create(:bookmark, user: attendee, event: event)

      delete "/api/v1/events/#{event.id}/bookmark", headers: auth_headers(attendee)

      expect(response).to have_http_status(:no_content)
      expect(attendee.bookmarks.count).to eq(0)
    end
  end

  describe "GET /api/v1/bookmarks" do
    it "lists the current attendee bookmarks" do
      create(:bookmark, user: attendee, event: event)

      get "/api/v1/bookmarks", headers: auth_headers(attendee)

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data.length).to eq(1)
      expect(data.first.dig("event", "id")).to eq(event.id)
    end
  end

  describe "GET /api/v1/events/:id" do
    it "shows bookmark counts to the organizer of the event" do
      create(:bookmark, user: attendee, event: event)

      get "/api/v1/events/#{event.id}", headers: auth_headers(organizer)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["bookmark_count"]).to eq(1)
    end

    it "hides bookmark counts from attendees" do
      create(:bookmark, user: attendee, event: event)

      get "/api/v1/events/#{event.id}", headers: auth_headers(attendee)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).not_to have_key("bookmark_count")
    end
  end
end
