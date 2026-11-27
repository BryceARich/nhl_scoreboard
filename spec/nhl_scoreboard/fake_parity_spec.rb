# frozen_string_literal: true

require_relative "../../lib/nhl_scoreboard"

# Layout code must run on the Mac and the Pi unchanged, so the fake must answer every call the real
# classes answer. This checks the names and arities, not the pixels.
RSpec.describe "the fake canvas and matrix" do
  def signature(klass, name)
    klass.instance_method(name).parameters
  end

  it "answers every public canvas method that Canvas has, with the same parameters" do
    %i[width height set_pixel fill clear draw_text].each do |name|
      expect(signature(NhlScoreboard::FakeCanvas, name))
        .to eq(signature(NhlScoreboard::Canvas, name)), "#{name} differs"
    end
  end

  it "answers every public matrix method that Matrix has, with the same parameters" do
    %i[canvas offscreen_canvas swap_on_vsync close].each do |name|
      expect(signature(NhlScoreboard::FakeMatrix, name))
        .to eq(signature(NhlScoreboard::Matrix, name)), "#{name} differs"
    end
  end
end
