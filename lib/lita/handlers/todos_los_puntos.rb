module Lita
  module Handlers
    class TodosLosPuntos < Handler
      require 'active_support/core_ext/integer/inflections'

      USER_POINTS_HASH_NAME = 'user_points'

      route(
        /\s*give\s+(\d+)\s+points? to @(\w+)/i,
        :add_points,
        help: {
          "give [n] points to @user" => "Adds [n] points to @user's score"
        }
      )

      route(
        /\s*take\s+(\d+)\s+points?\s+from\s+@(\w+)/i,
        :take_points,
        help: {
          "take [n] points from @user" => "Subtracts [n] points from @user's score"
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
          "whats the score" => "Replies with the top 2 users and their scores"
        }
      )

      def check_user_points(response)
        mention_name = response.matches[0][0]
        user = Lita::User.find_by_mention_name(mention_name)
        if user
          score = get_score_for_user(user)
          response.reply("@#{mention_name} has #{score['score']} points.")
        else
          response.reply("sorry. I can't find @#{mention_name}.")
        end
      end

      def check_score(response)
        scores = redis.hgetall(USER_POINTS_HASH_NAME)
        sorted_scores = scores.sort_by { |k, v| -Json.parse(v)['score'] }
        top_scores = sorted_scores.take(4)
        r = [ ]
        top_scores.each_with_index do |score, index|
          user = Lita::User.find_by_id(score_tuple.first)
          score = score_tuple.last
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
          set_score_for_user(user, score)
          response.reply("ok! @#{mention_name} has #{score['score']} points now.")
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
          set_score_for_user(user, score)
          response.reply("ok! @#{mention_name} has #{score['score']} points now.")
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
