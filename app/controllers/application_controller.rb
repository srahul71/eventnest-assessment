class ApplicationController < ActionController::API
  before_action :authenticate_user!
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  private

  def authenticate_user!
    @current_user = decoded_user_from_header
    render json: { error: "Unauthorized" }, status: :unauthorized unless @current_user
  rescue JWT::DecodeError, JWT::ExpiredSignature, ActiveRecord::RecordNotFound
    render json: { error: "Unauthorized" }, status: :unauthorized
  end

  def authenticate_optional_user!
    @current_user = decoded_user_from_header
  rescue JWT::DecodeError, JWT::ExpiredSignature, ActiveRecord::RecordNotFound
    @current_user = nil
  end

  def current_user
    @current_user
  end

  def render_forbidden(message = "Forbidden")
    render json: { error: message }, status: :forbidden
  end

  def render_not_found
    render json: { error: "Not found" }, status: :not_found
  end

  def decoded_user_from_header
    header = request.headers["Authorization"]
    token = header&.split(" ")&.last
    return nil if token.blank?

    decoded = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: "HS256")
    User.find(decoded[0]["user_id"])
  end
end
