class Api::V1::BaseController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def not_found
    render json: { errors: [{ status: "404", title: "Not Found" }] }, status: 404
  end
end