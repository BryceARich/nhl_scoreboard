# frozen_string_literal: true

require "socket"

module NhlScoreboard
  # A small local web server that shows the latest frame in a browser window and refreshes it a
  # few times a second. It uses only the standard library and listens on 127.0.0.1 only, so other
  # machines can't reach it. The fake matrix stands in for the panels; the browser is the window.
  #
  # @example
  #   server = NhlScoreboard::PreviewServer.new(port: 8080)
  #   server.publish(canvas, scale: 7)
  #   server.serve(server.listen) # then open http://127.0.0.1:8080 in a browser
  class PreviewServer
    # The page: an image of the latest frame, reloaded every 250 ms with a cache-busting query.
    PAGE = <<~HTML
      <!doctype html>
      <html>
      <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>Fake panels</title>
      <style>
        :root { color-scheme: dark; }
        body { margin: 0; min-height: 100vh; background: #111; display: flex; align-items: center; justify-content: center; }
        img { max-width: 100vw; max-height: 100vh; image-rendering: pixelated; }
      </style>
      </head>
      <body>
      <img id="frame" src="/frame.png" alt="fake LED panels">
      <script>
        setInterval(function () {
          document.getElementById("frame").src = "/frame.png?t=" + Date.now();
        }, 250);
      </script>
      </body>
      </html>
    HTML

    # @return [Integer] the port the server listens on.
    attr_reader :port

    # Makes a server. It doesn't listen until {#listen}.
    #
    # @param port [Integer] the TCP port; 0 picks a free one.
    # @param host [String] the address to bind; keep the default so only this machine can reach it.
    # @return [PreviewServer] the server.
    # @example
    #   NhlScoreboard::PreviewServer.new(port: 8080)
    def initialize(port: 8080, host: "127.0.0.1")
      @port = port
      @host = host
      @png = nil
      @mutex = Mutex.new
    end

    # Sets the frame the page shows. Safe to call from another thread while serving.
    #
    # @param canvas [FakeCanvas] the frame to show.
    # @param scale [Integer] the PNG cell size, as in {FakeCanvas#to_png}.
    # @return [nil]
    # @example
    #   server.publish(matrix.canvas, scale: 7)
    def publish(canvas, scale: 7)
      png = canvas.to_png(scale: scale)
      @mutex.synchronize { @png = png }
      nil
    end

    # Opens the listening socket.
    #
    # @return [TCPServer] the listening socket; pass it to {#serve}.
    # @raise [SystemCallError] if the port is in use.
    # @example
    #   listener = server.listen
    def listen
      TCPServer.new(@host, @port).tap { |listener| @port = listener.addr[1] }
    end

    # Accepts connections until interrupted, answering each one with {#handle}.
    #
    # @param listener [TCPServer] the socket from {#listen}.
    # @return [nil]
    # @example
    #   server.serve(server.listen)
    def serve(listener)
      loop do
        client = listener.accept
        begin
          handle(client)
        ensure
          client.close
        end
      end
    end

    # Answers one HTTP request on `io`. Serves the page at `/`, the latest PNG at `/frame.png` and
    # a 404 for anything else. It doesn't close `io`; {#serve} does.
    #
    # @param io [#gets, #write] the connection, a socket or any object with those methods.
    # @return [nil]
    # @example
    #   server.handle(StringIO.new("GET / HTTP/1.1\r\n\r\n"))
    def handle(io)
      request_line = io.gets.to_s
      loop do
        line = io.gets
        break if line.nil? || line == "\r\n" || line == "\n"
      end

      path = request_line.split[1].to_s.split("?").first
      case path
      when "/" then respond(io, "200 OK", "text/html; charset=utf-8", PAGE)
      when "/frame.png" then serve_frame(io)
      else respond(io, "404 Not Found", "text/plain; charset=utf-8", "not found")
      end
      nil
    end

    private

    def serve_frame(io)
      png = @mutex.synchronize { @png }
      if png
        respond(io, "200 OK", "image/png", png)
      else
        respond(io, "503 Service Unavailable", "text/plain; charset=utf-8", "no frame yet")
      end
    end

    def respond(io, status, type, body)
      io.write "HTTP/1.1 #{status}\r\n"
      io.write "Content-Type: #{type}\r\n"
      io.write "Content-Length: #{body.bytesize}\r\n"
      io.write "Cache-Control: no-store\r\n"
      io.write "Connection: close\r\n\r\n"
      io.write body
    end
  end
end
