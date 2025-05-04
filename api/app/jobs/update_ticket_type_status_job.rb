# frozen_string_literal: true

class UpdateTicketTypeStatusJob < ApplicationJob
  queue_as :default

  def perform
    service = TicketTypeStatusUpdateService.new
    service.update_status_based_on_time
    service.update_status_based_on_stock
  end
end
