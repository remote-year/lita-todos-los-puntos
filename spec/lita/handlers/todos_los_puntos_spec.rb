require "spec_helper"

describe Lita::Handlers::TodosLosPuntos, lita_handler: true do
  let(:robot) { Lita::Robot.new(registry) }
  subject { described_class.new(robot) }

  add_messages = [
    "give @john 15 points",
    "give @jane 1 point",
    "Give @john 15 points",
    "give @Jane 1 point.",
  ]

  add_messages.each do |message|
    it { is_expected.to route("@#{robot.name} #{message}").to(:add_points) }
  end

  take_messages = [
    "take 15 points from @john",
    "take 19 points from @john",
    "Take 15 points from @john",
    " take 19 points from @john",
  ]

  take_messages.each do |message|
    it { is_expected.to route("@#{robot.name} #{message}").to(:take_points) }
  end

  non_routable_messages = [
    "points 100",
    "all the points",
    "100 points",
    "give them points"
  ]
  non_routable_messages.each do |message|
    it { is_expected.to_not route("@#{robot.name} #{message}") }
  end
end
