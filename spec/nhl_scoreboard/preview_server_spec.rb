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

  it "keeps serving when a browser drops a connection mid-response" do
    server.publish(NhlScoreboard::FakeCanvas.new(width: 2, height: 2), scale: 1)
    connection = Struct.new(:input, :output) do
      def gets
        input.gets
      end

      def write(text)
        raise Errno::EPIPE unless output

        output.write(text)
      end

      def close
        nil
      end
    end
    dropped = connection.new(StringIO.new("GET / HTTP/1.1\r\n\r\n"), nil)
    served = connection.new(StringIO.new("GET /frame.png HTTP/1.1\r\n\r\n"), StringIO.new("".b))
    clients = [dropped, served]
    listener = Object.new
    listener.define_singleton_method(:accept) { clients.shift || raise(StandardError, "no more clients") }

    expect { server.serve(listener) }.to raise_error(StandardError, "no more clients")
    expect(served.output.string.b).to start_with("HTTP/1.1 200 OK".b)
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

  it "binds only to the loopback address by default" do
    expect(described_class.new.instance_variable_get(:@host)).to eq("127.0.0.1")
  end
end
