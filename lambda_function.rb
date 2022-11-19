require 'json'
require 'line/bot'
require 'aws-sdk-comprehend'

SENTIMENT = {
    "POSITIVE" => '好き',
    "NEGATIVE" => '嫌い',
    "NEUTRAL" => 'どうでもいい',
    "MIXED" => '気になってる'
}

def lambda_handler(event:, context:)
    signature = event['headers']['x-line-signature']
    body = event['body']

    unless client.validate_signature(body, signature)
        puts 'signature_error'
        return {statusCode: 400, body: JSON.generate('signature_error')}
    end

    events = client.parse_events_from(body)
    events. each do |e|
        case e
        when Line::Bot::Event::Message
            case e.type
            when Line::Bot::Event::MessageType::Text
                begin
                    texts = detect_sentiment(e.message['text'])
                    messages = texts.map do |text|
                        { type: 'text', text: text }
                    end
                    client.reply_message(e['replyToken'], messages)
                    { statusCode: 200, body: JSON.generate('Success') }
                rescue => error
                    messages = { type: 'text', text: "解析に失敗しました。" }
                    client.reply_message(e['replyToken'], messages)
                    { statusCode: 400, body: JSON.generate(error.message) }
                end
            end
        end
    end
end

def client
    @client ||= Line::Bot::Client.new { |config|
        config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
        config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
end

def detect_sentiment(text)
    client = Aws::Comprehend::Client.new(region: ENV["AWS_REGION"])
    language_code = client.detect_dominant_language({ text: text }).languages.max_by{ |lang| lang[:score] }[:language_code]
    result = client.detect_sentiment({text: text, language_code: language_code })
    sentiment = SENTIMENT[result[:sentiment]]
    score = result[:sentiment_score].to_h
    score_str = score.map{ |key, value| "#{SENTIMENT[key.to_s.upcase]}：#{(value * 100).round}％" }.join("\n")
    ["結果：#{sentiment}", score_str]
end
