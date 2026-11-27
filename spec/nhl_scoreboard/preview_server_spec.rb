# frozen_string_literal: true

require "stringio"
require_relative "../../lib/nhl_scoreboard"

RSpec.describe NhlScoreboard::PreviewServer do
  subject(:server) { described_class.new(port: 8080) }

  # Requests go through StringIO, so these specs never open a socket. The stand-in connection reads
  # the request from one buffer and collects the response in another.
  def request(path, verb: "GET")
    connection = Struct.new(:input, :output) do
      def gets
        input.gets
      end

      def write(text)
        output.write(text)
      end
    end.new(StringIO.new("#{verb} #{path} HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n"), StringIO.new("".b))
    server.handle(connection)
    connection.output.string.b
  end

  def status_line(response)
    response.lines.first.strip
  end

  def body_of(response)
    response.split("\r\n\r\n".b, 2).last
  end

  it "serves the page at /, with the frame image and a refresh script" do
    response = request("/")

    expect(status_line(response)).to eq("HTTP/1.1 200 OK")
    expect(response).to include("Content-Type: text/html")
    expect(body_of(response)).to include('src="/frame.png"').and include("setInterval")
  end

  it "answers 503 for the frame until one has been published" do
    expect(status_line(request("/frame.png"))).to eq("HTTP/1.1 503 Service Unavailable")
  end

  it "serves the latest published frame as a PNG" do
    canvas = NhlScoreboard::FakeCanvas.new(width: 4, height: 2)
    canvas.set_pixel(1, 1, 200, 10, 20)
    server.publish(canvas, scale: 2)

    response = request("/frame.png?t=123")

    expect(status_line(response)).to eq("HTTP/1.1 200 OK")
    expect(response).to include("Content-Type: image/png")
    expect(body_of(response).b).to start_with("\x89PNG\r\n\x1A\n".b)
    expect(body_of(response).b).to eq(canvas.to_png(scale: 2))
  end

  it "answers 404 for other paths" do
    expect(status_line(request("/nope"))).to eq("HTTP/1.1 404 Not Found")
  end

  it "keeps serving after a client drops its connection mid-response" do
    # The first client's socket breaks on the first write, as when a browser closes the page while a
    # frame is going out. The second client must still get a whole response. The fake listener
    # raises StopIteration when it runs out of clients, which `Kernel#loop` treats as the end.
    dropped = Struct.new(:input) do
      def gets = input.gets

      def write(_text) = raise(Errno::EPIPE)

      def close = nil
    end.new(StringIO.new("GET /frame.png HTTP/1.1\r\n\r\n"))

    output = StringIO.new("".b)
    served = Struct.new(:input, :output) do
      def gets = input.gets

      def write(text) = output.write(text)

      def close = nil
    end.new(StringIO.new("GET / HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n"), output)

    clients = [dropped, served]
    listener = Object.new
    listener.define_singleton_method(:accept) { clients.shift || raise(StopIteration) }

    expect { server.serve(listener) }.to output(/dropped a client connection \(Errno::EPIPE/).to_stderr
    expect(status_line(output.string.b)).to eq("HTTP/1.1 200 OK")
  end

  it "binds only to the loopback address by default" do
    expect(described_class.new.instance_variable_get(:@host)).to eq("127.0.0.1")
  end
end
