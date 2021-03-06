# Description:
#   Track tokens given to acknowledge contributions from others
#
# Dependencies:
#   None
#
# Configuration:
#   TOKEN_ALLOW_SELF
#   TOKENS_CAN_BE_TRANSFERRED
#   TOKEN_ALLOWANCE
#   ALLOWANCE_FREQUENCY
#   TIMEZONE
#
# Commands:
#   hubot give @username - Gives one token to `@username`.
#   hubot give a token to @username - Gives a token to `@username`.
#   hubot status @username - Returns the status of `@username`'s tokens.
#   hubot status of @username - Returns the status of `@username`'s tokens.
#   hubot show users - Returns a list of all the users that the bot knows about.
#   hubot who has tokens - Returns a list of all users who still have tokens to give out. Try to help these users so that they thank you with a token!
#   hubot who has tokens to give? - Returns a list of all users who still have tokens to give out. Try to help these users so that they thank you with a token!
#   hubot show users with tokens - Returns a list of all users who still have tokens to give out. Try to help these users so that they thank you with a token!
#   hubot leaderboard - Returns the top 10 users with the most tokens.
#   hubot show top n list - Returns the top n users with the most tokens, where n is a positive integer.
#   hubot vote @username - Cast a vote for `@username` in a contest to vote for the person who receives the most such votes.
#
# Author:
#   Charlie Brummitt <brummitt@gmail.com> Github:cbrummitt

# Environment variables:
#   TOKEN_ALLOW_SELF = false
#   TOKENS_CAN_BE_TRANSFERRED = true
#   TOKEN_ALLOWANCE = 5
#   BONUS_TOKENS = 3
#   ALLOWANCE_FREQUENCY = '59 59 23 * * 0'  # every Sunday at 11:59:59 PM; see https://github.com/kelektiv/node-cron#cron-ranges
#   TIMEZONE = "Africa/Accra"
#   RUN_VOTE_CONTEST = true
Util = require "util"  # for inspecting an object with `Util.inspect`
CronJob = require('cron').CronJob

# helper function that converts a string to a Boolean
# for using the Boolean environment variables TOKENS_CAN_BE_TRANSFERRED and TOKEN_ALLOW_SELF
stringToBool = (str) -> 
  if not str?
    return null
  else if str.match(/^(true|1|yes)$/i) != null
    return true
  else if str.match(/^(false|0|no)$/i) != null
    return false
  else
    return null

TOKEN_ALLOWANCE = parseInt(process.env.TOKEN_ALLOWANCE or 5, 10)
BONUS_TOKENS = parseInt(process.env.BONUS_TOKENS or 3, 10)
ROOM_ANNOUNCE_ALLOWANCE = process.env.ROOM_TO_ANNOUNCE_ALLOWANCE or "general"
TIMEZONE = process.env.TIMEZONE or "Africa/Accra"
FREQUENCY_RESET_WALLETS = process.env.ALLOWANCE_FREQUENCY or "59 59 23 * * 0"
RUN_VOTE_CONTEST = stringToBool(process.env.RUN_VOTE_CONTEST)

class TokenNetwork
  constructor: (@robot) ->
    # a dictionary mapping a user ID to a list of user IDs that specifies
    # whose tokens have been given to whom:
    # {sender_id : [recipient_1, recipient_2, ...], ...}
    @tokens_given = {}

    # a dictionary mapping a user ID to a list of user IDs that specifies
    # who has received tokens from whom:
    # {recipient_id: [sender_1, sender_2, ...], ...}
    @tokens_received = {}

    # a dictionary of how many tokens each person has available to give;
    # it maps each user's id to a non-negative integer
    @token_wallet = {}

    # a dictionary mapping user id's to the user id they have voted for
    @votes = {}

    # a list of dictionaries of who voted for whom
    @votes_history = []

    for own key, user of @robot.brain.users()
      @initialize_user(user['id'])

    # If the brain was already on, then set the cache to the dictionary
    # `@robot.brain.data.tokens_given`.
    # The fat arrow `=>` binds the current value of `this` (i.e., `@`)
    # on the spot.
    @robot.brain.on 'loaded', =>
      if @robot.brain.get('tokens_given')?
        @tokens_given = @robot.brain.get 'tokens_given'
      if @robot.brain.get('tokens_received')?
        @tokens_received = @robot.brain.get 'tokens_received'
      if @robot.brain.get('token_wallet')?
        @token_wallet = @robot.brain.get 'token_wallet'
      if @robot.brain.get('votes')?
        @votes = @robot.brain.get 'votes'

  recognize_user: (user_id) ->
    return (@tokens_given[user_id]? and
            @tokens_received[user_id]? and
            @token_wallet[user_id]?)

  initialize_user: (user_id) ->
    @tokens_given[user_id] = []
    @tokens_received[user_id] = []
    @token_wallet[user_id] = TOKEN_ALLOWANCE
    @save_token_data_to_brain()

  initialize_user_without_overwriting_data: (user_id) ->
    if not @tokens_given[user_id]?
      @tokens_given[user_id] = []
    if not @tokens_received[user_id]?
      @tokens_received[user_id] = []
    if not @token_wallet[user_id]?
      @token_wallet[user_id] = TOKEN_ALLOWANCE
    @save_token_data_to_brain()

  migrate_robot_brain_data_to_private_data: () ->
    # A fix for migrating data from robot.brain.data to robot._private
    summary_message = 'Migrated data: '
    if @robot.brain.data.tokens_given?
      summary_message += ' tokens_given'
      for own sender, recipients of @robot.brain.data.tokens_given
        # create a copy of the array
        @tokens_given[sender] = recipients.slice 0

    if @robot.brain.data.tokens_received?
      summary_message += ' tokens_received'
      for own recipient, senders of @robot.brain.data.tokens_received
        @tokens_received[recipient] = senders.slice 0

    if @robot.brain.data.token_wallet?
      summary_message += ' token_wallet'
      for own user_id, num_tokens of @robot.brain.data.token_wallet
        @token_wallet[user_id] = num_tokens

    if @robot.brain.data.votes?
      summary_message += 'votes '
      for own user_id, voted_id of @robot.brain.data.votes
        votes[user_id] = voted_id

    @save_token_data_to_brain()
    return summary_message

  fix_tokens_received: () ->
    summary_message = "Summary of fixing tokens received: \n"
    summary_message += @reset_tokens_received_to_empty()
    summary_message += "\n"
    summary_message += @populate_tokens_received()
    @save_token_data_to_brain()
    return summary_message

  reset_tokens_received_to_empty: () ->
    summary_message = "IDs of people who got their value set to empty: "
    for recipient, senders of @tokens_received
      if senders.length > 0
        summary_message += recipient + ", "
        @tokens_received[recipient] = []
    return summary_message

  populate_tokens_received: () ->
    summary_message = ""
    for sender, recipients of @tokens_given
      for recipient in recipients
        summary_message += "pushing " + sender + " onto recipient list of " + recipient + "\n"
        @tokens_received[recipient].push sender
    return summary_message

  save_token_data_to_brain: () ->
    @robot.brain.set 'tokens_given', @tokens_given
    @robot.brain.set 'tokens_received', @tokens_received
    @robot.brain.set 'token_wallet', @token_wallet
    @robot.brain.set 'votes', @votes

  initialize_user_if_unrecognized: (user_id) ->
    if not @recognize_user(user_id)
      @initialize_user(user_id)

  reset_everyones_wallet: () ->
    if RUN_VOTE_CONTEST
      result_beauty_contest = @compute_result_of_beauty_contest()
      for own key, user of @robot.brain.users()
        if user['id'] in result_beauty_contest.winner_user_ids
          @token_wallet[user['id']] = TOKEN_ALLOWANCE + BONUS_TOKENS
        else
          @token_wallet[user['id']] = TOKEN_ALLOWANCE
    else
      for own key, user of @robot.brain.users()
        @token_wallet[user['id']] = TOKEN_ALLOWANCE
    @robot.brain.set 'token_wallet', @token_wallet

  save_votes_to_brain: () ->
    votes_history = @robot.brain.get 'votes_history'
    if not votes_history?
      votes_history = []
    votes_history.push {
      'votes': @votes,
      'unix_time_milliseconds': Math.round(new Date().getTime())}
    @robot.brain.set 'votes_history', votes_history

  reset_votes: () -> 
    @votes = {}
    @robot.brain.set 'votes', @votes

  vote_recipient_of: (voter_id) ->
    if @votes[voter_id]?
      return "@" + @robot.brain.userForId(@votes[voter_id]).name
    else
      return null

  give_token: (sender, recipient, num_tokens_to_transfer) ->
    # Give a certain number of tokens from one user ID to another user ID.

    # Prepend `@` to the user names so that the users are notified by the
    # message generated by this method.
    sender_name = "@" + @robot.brain.userForId(sender).name
    recipient_name = "@" + @robot.brain.userForId(recipient).name

    if num_tokens_to_transfer == 0
      return "#{sender_name}: I can't let you send *zero* tokens :)"

    num_tokens_to_give = Math.min(num_tokens_to_transfer, @token_wallet[sender])
    if num_tokens_to_give <= 0
        return ("#{sender_name}: you do not have any more tokens available " + 
                "to give to others. You will have to wait until you receive " +
                "more tokens next week.")
        # TODO: is there a way to translate a cron time to an English
        # description and use that here? (instead of "next week")
    else
      # update @tokens_given
      @tokens_given[sender].push recipient for index in [1..num_tokens_to_give]

      # update @tokens_received
      @tokens_received[recipient].push sender for index in [1..num_tokens_to_give]

      # update @token_wallet
      @token_wallet[sender] = @token_wallet[sender] - num_tokens_to_give
      
      # update the key-value pairs in the robot's brain with the dictionaries
      # of tokens give, received, and wallet
      @save_token_data_to_brain()

      # create a message to be sent in the channel where the command was made
      token_or_tokens = if num_tokens_to_give != 1 then "tokens" else "token"
      message = ("#{sender_name} gave #{num_tokens_to_give} " + 
                 "#{token_or_tokens} to #{recipient_name}. ")
      tokens_remaining = @token_wallet[sender]
      token_or_tokens = if num_tokens_to_give != 1 then "tokens" else "token"
      message += ("#{sender_name} now has #{tokens_remaining} " + 
                  "#{token_or_tokens} remaining to give to others. ")
      return message

  selfDeniedResponses: (name) ->
    return [
      "Sorry #{name}. Tokens cannot be given to oneself.",
      "I can't do that #{name}. Tokens cannot be given to oneself.",
      "Tokens can only be given to other people.",
      "Nice try #{name}! Unfortunately I can't let you give a token to yourself."
    ]

  tally: (list_of_strings) -> 
    count = {}
    for x in list_of_strings
      if count[x]? then count[x] += 1 else count[x] = 1
    return count

  status: (id, self_bool) -> 
    # Return a string describing the status of a user.
    # The status is the number of tokens left in the user's wallet,
    # the number of tokens given and received (to whom and from whom).
    # Inputs: 
    #  1. id is the ID of the user for which we'll return the status; 
    #  2. self_bool is a boolean variable for whether the person writing this
    #     command is the same as the one for which we're returning the status
    # Example:
    # @name has 2 tokens remaining to give to others.
    # @name has given tokens to the following people: 
    #   @user_4 (1 token)
    #   @user_8 (2 tokens) 
    # @name has received 2 tokens from others: 
    #   @user_4 (1 token)
    #   @user_5 (1 token)

    name = if self_bool then "You" else "@" + @robot.brain.userForId(id).name

    # list of the people to whom `name` has given tokens
    tokens_given_by_this_person = if @tokens_given[id]? then @tokens_given[id] else []
    num_tokens_given = tokens_given_by_this_person.length
    # number of tokens this person has left to give others
    tokens_remaining = @token_wallet[id]

    # build up a string of results
    result = ""

    has_have = if self_bool then "have" else "has"
    token_or_tokens = if tokens_remaining != 1 then "tokens" else "token"
    result += ("#{name} #{has_have} #{tokens_remaining} #{token_or_tokens}" +
               " remaining to give to others. ")
    result += "\n"

    # number of tokens `name` has given to others (and to whom)
    if num_tokens_given > 0
      token_or_tokens = if num_tokens_given != 1 then "tokens" else "token"
      result += ("#{name} #{has_have} given #{num_tokens_given}" +
                 " #{token_or_tokens} to the following people: ")
      result += ("@" + @robot.brain.userForId(id_peer).name + " (" +
                 num_tokens.toString() + ")" for own id_peer, num_tokens of @tally(tokens_given_by_this_person)).join(", ")
    else
      result += "#{name} #{has_have} not given any tokens to other people. "
    result += "\n"


    # number of tokens `name` has received from others (and from whom)
    tokens_received_by_this_person = if @tokens_received[id]? then @tokens_received[id] else []
    num_tokens_received = tokens_received_by_this_person.length
    if num_tokens_received > 0
      token_or_tokens = if num_tokens_received != 1 then "tokens" else "token"
      result += ("#{name} #{has_have} received #{num_tokens_received} " + 
                 "#{token_or_tokens} from the following people: ")
      result += ("@" + @robot.brain.userForId(id_peer).name +
                 " (" + num_tokens.toString() + ")" for own id_peer, num_tokens of @tally(tokens_received_by_this_person)).join(", ")
    else
      do_or_does = if self_bool then "do" else "does"
      result += "#{name} #{do_or_does} not have any tokens from other people."
      if self_bool
        result += " Give feedback to others on their business ideas, so"
        result += " that they thank you by giving you a token!"
      else
        result += " If #{name} has given you useful feedback on your business"
        result += " idea, then make sure to thank them with a token by writing"
        result += " `/give #{name}`."

    #result += ("\n\n Debugging: \n tokens_given_by_this_person = " +
    #           "#{Util.inspect(tokens_given_by_this_person)} \n tokens_received_by_this_person = #{Util.inspect(tokens_received_by_this_person)}"
    return result

  leaderboard: (num_users) -> 
    user_num_tokens_received = (\
      [@robot.brain.userForId(user_id).name, received_list.length] \
      for own user_id, received_list of @tokens_received
    )

    if user_num_tokens_received.length == 0
      return "No one has received any tokens."

    # sort by the number of tokens received (in decreasing order)
    user_num_tokens_received.sort (a, b) ->
      if a[1] > b[1]
         return -1
      else if a[1] < b[1]
         return 1
      else
         return 0

    # # build up a string `str` 
    limit = Math.min(num_users, user_num_tokens_received.length) #5
    str = "These #{limit} users have currently been thanked the most:\n"
    for i in [0...limit]
      username = user_num_tokens_received[i][0]
      points = user_num_tokens_received[i][1]
      point_label = if points == 1 then "token" else "tokens"
      leader = ""
      newline = if i < limit - 1 then '\n' else ''
      str += "#{i+1}. @#{username} (#{points} " + point_label + ") " + leader + newline
    return str

  vote: (voter_id, voter_name, recipient_id, recipient_name) ->
    if not @recognize_user(voter_id)
      return "I did not recognize the user #{voter_name}."
    if not @recognize_user(recipient_id)
      return "I did not recognize the recipient of the vote #{recipient_name}."

    if @votes[voter_id]?
      previous_recipient = @votes[voter_id]
      previous_recipient_username = "@" + @robot.brain.userForId(previous_recipient).name
    else
      previous_recipient = null

    # Record the vote
    @votes[voter_id] = recipient_id
    @robot.brain.set 'votes', @votes
  
    if previous_recipient? and recipient_id == previous_recipient
      return "You are already scheduled to vote for #{recipient_name}."
    else if previous_recipient? and recipient_id != previous_recipient
      return "OK, I changed your vote from #{previous_recipient_username} to
        #{recipient_name}. This means that now you think that #{recipient_name}
        will win the most votes."
    else
      return "OK, I have recorded that you think #{recipient_name} will receive
        the most votes. If #{recipient_name} receives the most such votes, then
        you will receive #{BONUS_TOKENS} extra tokens next week. You can change
        your vote by voting for someone else."

  compute_result_of_beauty_contest: () ->
    # Tally the votes and figure out who voted for the people who received
    # the most votes.
    # Returns an object with keys
    #   winner_user_ids : list of user id's of people who voted for someone with the most votes
    #   winner_user_names : list of user names of people who voted for someone with the most votes
    #   most_votes_user_names : list of user names of people who received the most votes
    vote_recipients = (recipient for voter, recipient of @votes)
    vote_received_tally = @tally vote_recipients
    max_num_votes_received = Math.max (vote_count for recipient, vote_count of vote_received_tally)...

    winner_user_ids = []
    winner_user_names = []
    most_votes_user_names = []
    most_votes_ids = []
    for voter, recipient of @votes
      if vote_received_tally[recipient] == max_num_votes_received
        winner_user_ids.push voter
        winner_user_names.push ("@" + @robot.brain.userForId(voter).name)
        if recipient not in most_votes_ids
          most_votes_ids.push recipient
          most_votes_user_names.push ("@" + @robot.brain.userForId(recipient).name)

    result =
      winner_user_ids: winner_user_ids
      winner_user_names: winner_user_names
      most_votes_user_names: most_votes_user_names
    return result


# interpret strings that correspond to integers between 0 and 13
interpret_alphabetic_number = (str) ->
  switch str
    when "zero", "no", "none" then 0
    when "one", "a", "an" then 1
    when "two", "a couple of", "couple", "a pair of" then 2
    when "three", "a few", "few", "some" then 3
    when "four" then 4
    when "five", "several" then 5 # "a handful"
    when "six" then 6
    when "seven" then 7
    when "eight" then 8
    when "nine" then 9
    when "ten" then 10
    when "eleven" then 11
    when "twelve", "dozen", "a dozen" then 12
    when "thirteen", "baker's dozen", "a baker's dozen" then 13


# list of alternatives of names of numbers, to be used in regex's below
alphabetic_number_alternatives = """
zero|no|none|one|a|an|two|three|four|five|several|
six|seven|eight|nine|ten|eleven|twelve|thirteen|some"""


# convert a string to a nonnegative integer
fuzzy_string_to_nonnegative_int = (str) -> 
  if str.trim().search(/[0-9]+/i) != -1 # contains numerals
    return parseInt(str, 10)
  else if str.search(/[a-z ]+/i) != -1 # contains letters
    return interpret_alphabetic_number str.trim()
  else
    return NaN


# escape characters for regex
regexEscape = (str) ->
  return str.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&')


format_list_of_nouns = (list_strings) ->
  # Given a list of strings, return a string with the items separated by 'and'
  # if it is just two items, and by commas followed by an 'and' if it is 3 or
  # more items (with an Oxford comma).
  if list_strings.length == 0
    return ""
  if list_strings.length == 1
    return list_strings[0]
  if list_strings.length == 2
    return list_strings.join ' and '
  comma_joined = list_strings.slice(0, -1).join ', '
  comma_joined += ', and ' + list_strings.slice(-1)
  return comma_joined


module.exports = (robot) ->
  tokenBot = new TokenNetwork robot

  ###
    Environment variables
  ###

  # name of the bot 
  bot_name = process.env.HUBOT_ROCKETCHAT_BOTNAME or "token"
  bot_alias = process.env.HUBOT_ALIAS or "/"
  bot_user = robot.brain.usersForFuzzyName(bot_name)[0]
  if bot_user? 
    bot_id = bot_user.id
  else
    bot_id = ""

  # whether tokens can be given or received. defaults to true
  if process.env.TOKENS_CAN_BE_TRANSFERRED?
    tokens_can_be_given = stringToBool(
      process.env.TOKENS_CAN_BE_TRANSFERRED)
  else
    tokens_can_be_given = true

  # whether people can give tokens to themself. defaults to false.
  if process.env.TOKEN_ALLOW_SELF?
    allow_self = stringToBool(process.env.TOKEN_ALLOW_SELF)
  else
    allow_self = false

  # default length for the leaderboard showing the people with the most tokens
  leaderboard_length = 10

  reset_wallets_and_run_beauty_contest = () ->
    reset_wallets()
    if RUN_VOTE_CONTEST
      run_beauty_contest()

  # Reset everyone's wallet to the allowance environment variable
  reset_wallets = () ->
    all_mention = "@all"
    msg = "Hi #{all_mention} I just reset everyone's wallet to #{TOKEN_ALLOWANCE} tokens."
    msg += " Make sure to thank #{TOKEN_ALLOWANCE} people for giving useful feedback"
    msg += " on your business idea before these #{TOKEN_ALLOWANCE} tokens disappear"
    msg += " next week!"
    robot.messageRoom ROOM_ANNOUNCE_ALLOWANCE, msg
    tokenBot.reset_everyones_wallet()

  run_beauty_contest = () ->
    run_beauty_contest_without_resetting_votes()
    tokenBot.save_votes_to_brain()
    tokenBot.reset_votes()

  run_beauty_contest_without_resetting_votes = () ->
    result_beauty_contest = tokenBot.compute_result_of_beauty_contest()
    winner_names = result_beauty_contest.winner_user_names
    mosted_voted_names = result_beauty_contest.most_votes_user_names
    if winner_names.length >= 1
      winner_list = format_list_of_nouns winner_names
      most_voted_list = format_list_of_nouns mosted_voted_names
      person_people_win = if winner_names.length > 1 then "people" else "person"
      person_people_voted = if mosted_voted_names.length > 1 then "people" else "person"
      was_were_voted = if mosted_voted_names.length > 1 then "were" else "was"
      msg = "I tallied the votes of the contest. *The following
        #{person_people_win} voted for the #{person_people_voted} who received
        the most votes*, so they receive #{BONUS_TOKENS} extra tokens: \n\n
        #{winner_list} :tada: :fireworks: :clap: :grin: \n\n
        Congratulations on choosing the #{person_people_voted} who received
        the most votes! \n\n *The #{person_people_voted} who received the most
        votes* #{was_were_voted} #{most_voted_list} . Nice work #{most_voted_list} ! :thumbsup:"
      robot.messageRoom ROOM_ANNOUNCE_ALLOWANCE, msg

  job = new CronJob(FREQUENCY_RESET_WALLETS, (->
    do reset_wallets_and_run_beauty_contest
  ), null, true, TIMEZONE)
 
  give_regex_string = "give|send"
  number_regex_string = "[0-9]+" + "|" + alphabetic_number_alternatives
  give_regex_string = "" +
    "\\b(" + give_regex_string +   # give or send (first capturing group)
    ")\\b" +  
    "(?:\\s+" +                    # number of tokens is optional (second capturing group)
    "\\b(" + number_regex_string + "|all" + ")\\b" + 
    ")?" +
    "(?:\\s+tokens{0,1})?" +       # token or tokens (optional)
    "(?:\\s+\\b(?:to)\\b)?" +      # to (optional)
    "\\s+" +                       # at least 1 charachter of whitespace
    "@?([\\w.\\-]+)" +             # user name or name (to be matched in a fuzzy way below) -- third capture group
    "\\s*$"                        # 0 or more whitespace
  give_regex = new RegExp(give_regex_string, "i")

  # respond to give commands
  robot.respond give_regex, (res) ->  # `res` is an instance of Response. 
    sender = res.message.user
    sender_name = "@" + res.message.user.name
    sender_id = res.message.user.id
    tokenBot.initialize_user_if_unrecognized sender_id

    # is the message a DM to the bot?
    # a message is a direct message if the message's room contains the
    # sender_id (because the room ID is a concatenation of the IDs of the
    # sender and recipients)
    is_direct_message = (res.message.room.indexOf(sender_id) > -1)

    # check whether the transferring tokens is frozen; 
    # if so, send a message and return
    if not tokens_can_be_given
      res.send "Sorry #{sender_name}, tokens cannot be given right now."
      robot.logger.info ("User {id: #{sender_id}, name: #{sender_name}} tried" + 
                          " to give a token but tokens cannot be given now.")
      return
    
    # figure out who the recipient is 
    recipient_name_raw = res.match[3] # third capture group in give_regex
    recipients = robot.brain.usersForFuzzyName(recipient_name_raw.trim()) 
    
    # check whether we identified just one person with that user name
    # if not, send a failure message and return
    if recipients.length != 1
      gave_to_bot = ((recipients.length >= 1 and recipients[0] == bot_name) or
        recipient_name_raw.indexOf(bot_name) != -1)
      if gave_to_bot
        give_to_bot_responses = [
          "Thanks #{sender_name} for offering to give me a token! We'll consider
            that just a practice round :relaxed: When you give tokens to
            other people (and not to me, the :robot:), then I will actually
            transfer a token from you to them.",
          "Aw, thanks #{sender_name}. I won't actually transfer a token from 
            you to me. I keep track of all the tokens! :nerd_face: ",
          "Way to go #{sender_name}, that's how you give tokens! :thumbsup:
            Don't worry; that one was just a practice. :wink: "]
        res.send res.random give_to_bot_responses
        return
      else
        fail_message = "Sorry #{sender_name}, I didn't understand that person 
          ( `#{recipient_name_raw}` ) to whom you're trying to give a token.
          \n\nMake sure that you enter the person's user name correctly,
          either with or without a preceding @ symbol, such as `/give @username`.
          Also, if you did enter that person's user name correctly,
          I won't be able to give them a token from you until that
          person has sent at least one message in any channel."
        res.send fail_message
        return

    # Now we know who the recipient is
    recipient = recipients[0]
    recipient_name = "@" + recipient.name
    recipient_id = recipient.id

    # Check whether the sender is trying to give a token to himself/herself and
    # allow_self is false. If so, return a random message saying that you can't
    # give a token to yourself.
    if not allow_self and res.message.user.id == recipient_id
      res.send res.random tokenBot.selfDeniedResponses(sender_name)
      log_message = ("User {id: #{sender_id}, name: #{sender_name}} tried to" +
                     " give himself/herself a token")
      robot.logger.info log_message
      return

    # figure out how many tokens they want to give
    # if the user doesn't provide a number, then assume that the number is 1
    num_tokens_to_transfer = switch
      when not res.match[2]? or res.match[2] == "" then 1
      when res.match[2] == "all" then tokenBot.token_wallet[sender_id]
      else fuzzy_string_to_nonnegative_int res.match[2]

    if num_tokens_to_transfer? and not isNaN num_tokens_to_transfer
      log_message = "{action: give, "
      log_message += "sender: {id: #{sender_id}, name: #{sender_name}}, "
      log_message += "recipient: {id: #{recipient_id}, name: #{recipient_name}}, "
      log_message += "is_direct_message: #{is_direct_message}, "
      log_message += "numtokens: #{num_tokens_to_transfer}}"
      robot.logger.info log_message
      message = tokenBot.give_token sender_id, recipient_id, num_tokens_to_transfer
      res.send message
    else
      fail_message = "I didn't understand how many tokens you want to give.
        If you don't provide a number, I assume you want to 
        give one token. I also understand numbers like 1, 2,
        3 and some alphabetic numbers like one, two, three."
      res.send fail_message
    return

  ###
    Status and leaderboard commands 
  ###

  # respond to "status (of) @user"
  robot.respond ///
                status        # "status"
                (?:\s+of)?    # "of" is optional
                \s+           # whitespace
                @?([\w.\-]+)  # user name or name (to be matched in a fuzzy way below). 
                              # \w matches any word character (alphanumeric and underscore).
                \s*$          # 0 or more whitespace
                ///i, (res) ->

    name_raw = res.match[1]
    # the second capture group is the user name:
    users = robot.brain.usersForFuzzyName(name_raw.trim())

    if users.length == 1
      user = users[0]
      # whether the person writing the command is the one we're getting the status of
      self_bool = (user['id'] == res.message.user.id)
      tokenBot.initialize_user_if_unrecognized user['id']
      res.sendPrivate tokenBot.status user['id'], self_bool
    else
      res.sendPrivate "Sorry, I couldn't understand the name you provided ( `#{name_raw}` )."

  # Listen for the command `status` without any user name provided.
  # This sends the message returned by `tokenBot.status` on the input `res.message.user.name`.
  robot.respond ///
                \s*
                status
                \s*
                $///i, (res) ->
    tokenBot.initialize_user_if_unrecognized res.message.user.id
    res.sendPrivate tokenBot.status res.message.user.id, true

  # show leaderboard, show leader board
  robot.respond /\s*(?:show )?\s*leaders? ?board\s*/i, (res) ->
    res.sendPrivate tokenBot.leaderboard leaderboard_length

  # who has the most tokens? 
  robot.respond /\s*who \b(has|holds)\b the most tokens\??\s*/i, (res) ->
    res.sendPrivate tokenBot.leaderboard leaderboard_length

  # show top n list
  show_top_n_regex_string = "" +
    "(?:show)?" +         # "show" is optional
    "\\s+" +              # whitespace
    "(?:the\s+)?" +       # "the" is optional
    "top" +               # "top" is required
    "\\s+" +              # whitespace
    "(" + number_regex_string + ")" +     # length of leaderboard, such as "5" or "five"
    "(?:\\s+\\b(list|users|people)?\\b)?" # "list" or "users" or "people" is optional
  
  show_top_n_regex = new RegExp(show_top_n_regex_string, "i")

  robot.respond show_top_n_regex, (res) -> 
    # grab the length of the leaderboard (the first capturing group)
    number_input = res.match[1]

    number_parseInt = switch
      when number_input == "" or not number_input? then leaderboard_length # default value
      when number_input == "all" then robot.brain.users().length
      else fuzzy_string_to_nonnegative_int number_input

    # if we can successfully parse number_input as a base-10 integer, 
    # then send the result of tokenBot.leaderboard
    if not isNaN number_parseInt
      if number_parseInt > 0
        res.sendPrivate tokenBot.leaderboard number_parseInt
      else
        msg = "Please provide a positive integer; for example, use the "
        msg += "command `#{bot_name} show top 5 list`."
        res.send msg
    else
      # it's not an integer, so try to interpret an English word for a number
      number_interpreted = interpret_alphabetic_number number_input
      if isNaN number_interpreted
        fail_message = "Sorry, I didn't understand the number you provided 
          (` #{number_input} `). Use the command `#{bot_name} show leaderboard`
          to show the top #{leaderboard_length} list, or use `#{bot_name} show
          top n list` (where `n` is an integer) to show the `n`
          people who have received the most tokens."
        res.sendPrivate fail_message
      else
        res.sendPrivate tokenBot.leaderboard number_interpreted

  ###
    Vote command
  ###

  #respond to "vote (for) @user"
  robot.respond ///
                vote          # "vote"
                (?:\s+for)?   # "for" is optional
                \s+           # whitespace
                @?([\w.\-]+)  # user name or name (to be matched in a fuzzy way below). 
                              # \w matches any word character (alphanumeric and underscore).
                \s*$          # 0 or more whitespace
                ///i, (res) ->

    if not RUN_VOTE_CONTEST
      res.sendPrivate "There is currently no ongoing contest for voting for the
        person whom you think will receive the most votes."
      return
    voter = res.message.user
    voter_name = "@" + res.message.user.name
    voter_id = res.message.user.id
    tokenBot.initialize_user_if_unrecognized voter_id

    name_raw = res.match[1]
    users = robot.brain.usersForFuzzyName(name_raw.trim())
    if users.length == 1
      recipient = users[0]
      recipient_name = "@" + recipient.name
      recipient_id = recipient.id
      tokenBot.initialize_user_if_unrecognized recipient_id

      # forbid people from voting for themselves
      voting_for_self = (recipient_id == voter_id)
      if voting_for_self
        msg = "Sorry #{voter_name}, I can't let you vote for yourself.
          You must vote for someone else. To do so,
          send the command `/vote @username`, where `@username` is the username
          of the person who you think will win the most votes."
        previous_recipient = tokenBot.vote_recipient_of(voter_id)
        if previous_recipient?
          msg += "\n\nYour vote is still scheduled for #{previous_recipient}."
        res.sendPrivate msg
      else
        msg = tokenBot.vote(voter_id, voter_name, recipient_id, recipient_name)
        res.sendPrivate msg

        log_message = "{action: vote, "
        log_message += "voter: {id: #{voter_id}, name: #{voter_name}}, "
        log_message += "recipient: {id: #{recipient_id}, name: #{recipient_name}}}"
        robot.logger.info log_message
    else
      res.sendPrivate "Sorry, I couldn't understand the name you provided ( `#{name_raw}` )."

  ###
    Miscellaneous commands
  ###

  #log all errors 
  robot.error (err, res) ->
    robot.logger.error "#{err}\n#{err.stack}"
    if res?
       res.reply "#{err}\n#{err.stack}"

  # show user with tokens still to give out to others
  robot.respond ///
                \s*
                \b(show)?\s*
                \b(the)?\s*
                \b(people|everyone|users)?\s*
                \b(who|with)\s*
                \b(still)?\s*
                \b(has|have)\s*
                \b(tokens)
                \b(to give\b(out)?)?
                \s*\??
                \s*
                ///i, (res) ->
    sender_id = res.message.user.id
    tokenBot.initialize_user_if_unrecognized sender_id
    # check whether tokenBot.tokens_given is empty
    if Object.keys(tokenBot.tokens_given).length == 0
      msg = "No one has said anything yet, so I don't know of the existence of anyone yet!"
      res.sendPrivate msg
    else
      response = ""
      for own id, tokens_remaining of tokenBot.token_wallet
        if tokens_remaining > 0
          username = "@" + robot.brain.userForId(id).name
          token_or_tokens = if tokens_remaining != 1 then "tokens" else "token"
          if response != ""
            response += ", "
          response += "#{username} (#{tokens_remaining} #{token_or_tokens})"
      if response == ""
        res.sendPrivate "Everyone has given out all their tokens."
      else
        preamble = "The following users still have tokens to give. Try to help"
        preamble += " these users so that they thank you with a token!\n"
        res.sendPrivate (preamble + response)

  # if this is the first time that this user has said something, then
  # initialize this user in the dictionaries of tokens sent, tokens received,
  # and tokens available to give
  robot.hear /.*/i, (res) ->
    sender_id = res.message.user.id
    tokenBot.initialize_user_if_unrecognized sender_id

  # # when a user enters the room, initialize them in the tokenBot's dictionaries
  # # if this user's ID is not already a key in those dictionaries
  robot.enter (res) -> 
    sender_id = res.message.user.id
    tokenBot.initialize_user_if_unrecognized sender_id

  robot.respond /hi|hello|hey/i, (res) ->
    sender = res.message.user
    sender_name = "@" + res.message.user.name
    res.send "Hi #{sender_name}!"

  robot.respond /(what is|what's) your name\??/i, (res) -> 
    res.send "My name is #{bot_name}. You can give commands in the form `#{bot_name} <command>`."
    #res.send "My ID is #{Util.inspect robot.brain.usersForFuzzyName(bot_name.trim())}"

  robot.hear /how do I \b(?:give|send)\b(?:\s+a)? tokens?\??/i, (res) -> 
    res.send "Use the command `/give @username`."

  ###
    DEBUGGING
  ###
  # inspect a user's user name
  robot.respond /inspect me/i, (res) ->
    user = robot.brain.userForId(res.message.user.id)
    res.send "#{Util.inspect(user)}"

  # show users, show all users -- show all users and their user names
  robot.respond /show (?:all )?users$/i, (res) ->
    msg = "Here are all the users I know about: "
    msg += format_list_of_nouns("@#{user.name}" for own key, user of robot.brain.users())
    res.send msg

  robot.respond /show your brain/i, (res) -> 
    res.send "robot.brain.users() = #{Util.inspect(robot.brain.users())}"
    res.send "robot.brain.get 'tokens_given' = #{Util.inspect(robot.brain.get 'tokens_given')}"
    res.send "robot.brain.get 'tokens_received' = #{Util.inspect(robot.brain.get 'tokens_received')}"
    res.send "robot.brain.get 'token_wallet' = #{Util.inspect(robot.brain.get 'token_wallet')}"
    res.send "robot.brain.get 'votes' = #{Util.inspect(robot.brain.get 'votes')}"
    res.send "Util.inspect robot.brain = #{ Util.inspect robot.brain }"

  robot.respond /show token's data/i, (res) ->
    res.send "tokenBot.tokens_given = #{Util.inspect(tokenBot.tokens_given)}"
    res.send "tokenBot.tokens_received = #{Util.inspect(tokenBot.tokens_received)}"
    res.send "tokenBot.token_wallet = #{Util.inspect(tokenBot.token_wallet)}"
    res.send "tokenBot.votes = #{Util.inspect(tokenBot.votes)}"

  robot.respond /show robot.brain.data/i, (res) ->
    res.send "robot.brain.data.tokens_given = #{Util.inspect(robot.brain.data.tokens_given)}"
    res.send "robot.brain.data.tokens_received = #{Util.inspect(robot.brain.data.tokens_received)}"
    res.send "robot.brain.data.token_wallet = #{Util.inspect(robot.brain.data.token_wallet)}"
    res.send "robot.brain.data.votes = #{Util.inspect(robot.brain.data.votes)}"

  robot.respond /what time zone are you on?/i, (res) ->
    res.send "I am on time zone #{TIMEZONE}."

  robot.respond /how many tokens do we get each week?/i, (res) ->
    res.send "Everyone gets #{TOKEN_ALLOWANCE} tokens each week."

  robot.respond /when will wallets be reset?/i, (res) ->
    res.send "The frequency of resetting wallets is #{FREQUENCY_RESET_WALLETS}."

  robot.respond /is the vote contest running?/i, (res) ->
    if RUN_VOTE_CONTEST
      res.send "Yes, the vote contest is occurring."
    else
      res.send "No, the vote contest is not occurring."

  robot.respond /fix_tokens_received/i, (res) ->
    res.send "Fixing tokens_received..."
    res.send tokenBot.fix_tokens_received()
