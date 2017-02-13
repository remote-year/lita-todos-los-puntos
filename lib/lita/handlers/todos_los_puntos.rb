module Lita
  module Handlers
    class TodosLosPuntos < Handler
      require 'active_support/core_ext/integer/inflections'

      USER_POINTS_HASH_NAME = 'user_points'

      route(
        /\s*give\s+(\d+)\s+points?\s+to\s+@(\w+)\s*(for\s+(.+))?/i,
        :add_points,
        help: {
          "give [n] points to @user" => "Adds [n] points to @user's score",
          "give [n] points to @user for [something]" => "Adds [n] points to @user's score for [something]"
        }
      )

      route(
        /\s*take\s+(\d+)\s+points?\s+from\s+@(\w+)\s*(for\s+(.+))?/i,
        :take_points,
        help: {
          "take [n] points from @user" => "Subtracts [n] points from @user's score",
          "take [n] points from @user for [something]" => "Subtracts [n] points from @user's score for [something]"
        }
      )

      route(
        /\s*how\s+many\s+points\s+does\s+@(\w+)\s+have/i,
        :check_user_points,
        help: {
          "how many points does @user have" => "Replies with @user's score"
        }
      )

      route(
        /(whats|what is|what's) the score/i,
        :check_score,
        help: {
          "whats the score" => "Replies with the top 4 users and their scores"
        }
      )

      def check_user_points(response)
        mention_name = response.matches[0][0]
        user = Lita::User.find_by_mention_name(mention_name)
        if user
          score = get_score_for_user(user)
          response.reply("@#{mention_name} has #{score['score']} points.")
          unless score['give_reasons'].empty?
            response.reply("@#{mention_name} has gained points for #{score['give_reasons'].shuffle.take(10).join(', ')}")
          end
          unless score['take_reasons'].empty?
            response.reply("@#{mention_name} has lost points for #{score['take_reasons'].shuffle.take(10).join(', ')}")
          end
        else
          response.reply("sorry. I can't find @#{mention_name}.")
        end
      end

      def check_score(response)
        scores = redis.hgetall(USER_POINTS_HASH_NAME).map { |k, v| [ k, JSON.parse(v) ] }
        sorted_scores = scores.sort_by { |k, v| -(v['score']) }
        top_scores = sorted_scores.take(4)
        r = [ ]
        top_scores.each_with_index do |score_data, index|
          user = Lita::User.find_by_id(score_data.first)
          score = score_data.last
          r << "In #{(index + 1).ordinalize} place with #{score['score']} points: @#{user.mention_name}"
        end
        response.reply(r.join("\n"))
      end

      def add_points(response)
        mention_name = response.matches[0][1]
        user = Lita::User.find_by_mention_name(mention_name)
        if user
          score = get_score_for_user(user)
          additional_points = Integer(response.matches[0][0])
          score['score'] += additional_points
          give_reason = response.matches[0][3]
          if give_reason
            score['give_reasons'] << give_reason
            score['give_reasons'].uniq!
          end
          set_score_for_user(user, score)
          response.reply("ok!")
          response.reply("@#{mention_name} gained #{additional_points} points for #{give_reason}") if give_reason
          response.reply("@#{mention_name} has #{score['score']} points now in total.")
        else
          response.reply("sorry. I can't find @#{mention_name}.")
        end
      end

      def take_points(response)
        mention_name = response.matches[0][1]
        user = Lita::User.find_by_mention_name(mention_name)
        if user
          score = get_score_for_user(user)
          taken_points = Integer(response.matches[0][0])
          score['score'] -= taken_points
          take_reason = response.matches[0][3]
          if take_reason
            score['take_reasons'] << take_reason
            score['take_reasons'].uniq!
          end
          set_score_for_user(user, score)
          response.reply("ok!")
          response.reply("@#{mention_name} lost #{taken_points} points for #{take_reason}") if take_reason
          response.reply("@#{mention_name} has #{score['score']} points now in total.")
        else
          response.reply("sorry. I can't find @#{mention_name}.")
        end
      end

      def set_score_for_user(user, score)
        redis.hset(USER_POINTS_HASH_NAME, user.id, score.to_json)
      end

      def get_score_for_user(user)
        existing_score = redis.hget(USER_POINTS_HASH_NAME, user.id)
        if existing_score
          JSON.parse(existing_score)
        else
          { 'score' => 0, 'give_reasons' => [ ], 'take_reasons' => [ ] }
        end
      end

      Lita.register_handler(self)
    end
  end
end
