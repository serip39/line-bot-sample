require 'sinatra'   # gem 'sinatra'
require 'line/bot'  # gem 'line-bot-api'
require 'net/http'

configure {
  set :server, :puma
}

SECRET_KEY = ENV["API_SECRET"]

class Pumatra < Sinatra::Base

  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
  end

  def dr_api(line_user_id)
    tt = Time.now.to_i
    url_str = "https://staging.saibugas.dr-electricity.com/api/v1/line_messages/participations"
    uri = URI.parse(url_str)
    uri.query = URI.encode_www_form({ tt: })
    headers = {
      'Content-Type': 'application/json',
      'X-Dr-Authorization': Digest::SHA256.hexdigest("#{url_str}?tt=#{tt}:#{SECRET_KEY}"),
      'origin': 'https://line-bot.dr-electricity.com'
    }
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme === "https"
    params = {
      mypage_id: tt,
      supply_point_number: '900000012345600000000',
      customer_number: '123456',
      line_user_id:
    }
    begin
      response = http.post(uri.request_uri, params.to_json, headers)
      puts response.code
      puts response.message
      puts response.read_body
    rescue StandardError => e
      puts e.message
    end
  end

  get '/' do
    "Hello World"
  end

  post '/callback' do
    body = request.body.read

    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      halt 400, {'Content-Type' => 'text/plain'}, 'Bad Request'
    end

    events = client.parse_events_from(body)

    events.each do |event|
      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          if event.message['text'] == 'みんなで節電キャンペーン'
            user_id = event['source']['userId']
            puts "userId:#{user_id}"
            dr_api(user_id)
          else
            message = {
              type: 'text',
              text: event.message['text']
            }
            client.reply_message(event['replyToken'], message)
          end
        end
      end
    end

    "OK"
  end

  run! if app_file == $0
end
