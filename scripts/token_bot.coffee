# Description:
#   Track tokens given to acknowledge contributions from others
#
# Dependencies:
#   None
#
# Configuration:
#   TOKEN_ALLOW_SELF
#   TOKENS_CAN_BE_TRANSFERRED
#   TOKENS_ENDOWED_TO_EACH_USER
#
# Commands:
#   hubot give a token to @user_name - Gives a token to `@user_name`. The words 'token', 'a' and 'to' are optional.
#   hubot revoke a token from @user_name` - Revokes a token from `@user_name`. The words 'token', 'a' and 'from' are optional.
#   hubot token status of @user_name - Returns the status of `@user_name`'s tokens. 'of' is optional.
#   hubot show all users - Returns a list of all the users that the bot knows about. 'all' is optional.
#   hubot who has tokens to give? - Returns a list of all users who still have tokens to give out. Try to help these users so that they thank you with a token!
#   hubot show users with tokens - Returns a list of all users who still have tokens to give out. Try to help these users so that they thank you with a token!
#   hubot show leaderboard - Returns the top 10 users with the most tokens.
#   hubot show top n list - Returns the top n users with the most tokens, where n is a positive integer.
#
# Author:
#   cbrummitt


# Environment variables:
#   TOKEN_ALLOW_SELF = false
#   TOKENS_CAN_BE_TRANSFERRED = true
#   TOKENS_ENDOWED_TO_EACH_USER = 5



## TODO: Update the commands list above. 
## From the scripting documentation: 


#### Commands from karma bot: 
#   <thing>++ - give thing some karma
#   <thing>-- - take away some of thing's karma
#   hubot karma <thing> - check thing's karma (if <thing> is omitted, show the top 5)
#   hubot karma empty <thing> - empty a thing's karma
#   hubot karma best - show the top 5
#   hubot karma worst - show the bottom 5


# TODO: Other features we might want
# a command to show a leader board list of people with the most tokens received?
# find people who have tokens to give?

# TODO: Do I need to use the save command to get persistence of the data? 
# Currently the data disappears when I `git heroku push` new code.
# See the source code at https://github.com/github/hubot/blob/master/src/brain.coffee



class TokenNetwork
  #### Constructor ####
  constructor: (@robot) -> 
    # a dictionary of whose tokens have been given to whom. The data is in the form 
    #     sender : [recipient1, recipient2, ...]
    @tokens_given = {}


    # a dictionary of who has received tokens from whom. The data is in the form 
    #     recipient : [sender1, sender2, ...]
    @tokens_received = {}

    #for user of 
    for own key, user of robot.brain.data.users
      @tokens_given[user['id']] = []
      @tokens_received[user['id']] = []
    
    # each user can give at most this many tokens to others
    @max_tokens_per_user = process.env.TOKENS_ENDOWED_TO_EACH_USER or 5 

    # variable that determines whether tokens can be given right now
    # TDOO: write a method that will turn this off and display a message in #general telling everyone that tokens can no longer be given?
    # TODO: make these environment variables ` ... = process.env.HUBOT_CAN_TRANSFER_TOKENS or true`
    #@tokens_can_be_given = true
    #@tokens_can_be_revoked = true

    # list of responses to display when someone receives or gives a token
    # TODO: send messages like these? 
    @receive_token_responses = ["received a token!", "was thanked with a token!"]
    @revoke_token_responses = ["lost a token :(", "had a token revoked"]

    # if the brain was already on, then set the cache to the dictionary @robot.brain.data.tokens_given
    # the fat arrow `=>` binds the current value of `this` (i.e., `@`) on the spot

    # TODO: do we want to use this snippet? https://github.com/github/hubot/issues/880#issuecomment-81386478
    @robot.brain.on 'loaded', =>
      if @robot.brain.data.tokens_given
        @tokens_given = @robot.brain.data.tokens_given
      if @robot.brain.data.tokens_received
        @tokens_received = @robot.brain.data.tokens_received


  #### Methods ####

  give_or_revoke_token: (sender, recipient, num_tokens_to_transfer, give_bool) -> 
    # `give_token` gives a token from the sender to recipient. It returns a message to send to the chat channel. 
    # The inputs `sender` and `recipient` are user ID's. 
    # we know that tokens can be given (i.e., process.env.TOKENS_CAN_BE_TRANSFERRED == 'true') because that's handled by the response.
    
    # get the names of these users
    sender_name = "@" + @robot.brain.userForId(sender).name
    recipient_name = "@" + @robot.brain.userForId(recipient).name
      
    # check whether @tokens_given[sender], @tokens_received[recipient], @tokens_given[recipient], @tokens_received[sender]
    # exist and if not set each one to []
    if @tokens_given[sender]? == false # if @tokens_given[sender] has not yet been defined (i.e., it's null or undefined)
      @tokens_given[sender] = []
    if @tokens_received[recipient]? == false
      @tokens_received[recipient] = []
    if @tokens_given[recipient]? == false
      @tokens_given[recipient] = []
    if @tokens_received[sender]? == false
      @tokens_received[sender] = []

    # if we are giving (rather than revoking) 
    if give_bool
      # if the sender has not already given out more that `@max_tokens_per_user` tokens, then add recepient to @cacheTokens[sender]'s list.
      # note that this allows someone to send multiple tokens to the same user
      if @tokens_given[sender].length >= @max_tokens_per_user
        return "#{sender_name}: you do not have any more tokens available to give to others. If you want, revoke a token using the command `token revoke a token from @user_name`."
      else 
        # compute the number of tokens this user can give
        num_tokens_to_give = Math.min(num_tokens_to_transfer, @max_tokens_per_user - @tokens_given[sender].length)
        # update @tokens_given 
        if num_tokens_to_give > 0
          @tokens_given[sender].push recipient for index in [1..num_tokens_to_give]
          @robot.brain.data.tokens_given = @tokens_given

          # update @tokens_received
          @tokens_received[recipient].push sender for index in [1..num_tokens_to_give]
          @robot.brain.data.tokens_received = @tokens_received

        message = "#{sender_name} gave " + num_tokens_to_give + " token" + (if num_tokens_to_give != 1 then "s" else "") + " to #{recipient_name}. " 
        tokens_remaining = @max_tokens_per_user - @tokens_given[sender].length
        message += "#{sender_name} now has #{tokens_remaining} token" + (if tokens_remaining != 1 then "s" else "") + " remaining to give to others. "

        return message 
        #message += "\n#{recipient} has received tokens from the following: " # #{@tokens_received[recipient]}."
        #for own name_peer, number of @tally(@tokens_received[recipient])
        #  result += "#{name_peer} (#{number} token" + (if number != 1 then "s" else "") + ") "
        #result += (name_peer + " (" + num_tokens.toString() + ")" for own name_peer, num_tokens of @tally(@tokens_received[recipient])).join(", ")
    
    else # otherwise we are revoking

      # check whether @tokens_given[sender] or @tokens_received[recipient] is null or undefined
      if not @tokens_given[sender]?
        return "@#{sender_name} has not given tokens to anyone, so I cannot revoke any tokens. Give tokens using the command `token give token @user_name`."
      else if not @tokens_received[recipient]
        return "@#{recipient_name} does not hold any tokens from anyone." 
      else # sender has sent >=1 token to someone, and recipient has received >=1 token from someone
        
        # compute the number of tokens this user can revoke
        num_tokens_sender_has_given_recipient = (i for i in @tokens_given[sender] when i == recipient).length
        num_tokens_to_revoke = Math.min(num_tokens_to_transfer, num_tokens_sender_has_given_recipient)
        
        if num_tokens_to_revoke <= 0
          return "#{sender_name}: #{recipient_name} does not have any tokens from you, so you cannot revoke a token from #{recipient_name}."
        else
          # remove the first occurrence of recipient in the list @tokens_given[sender]
          for index in [1..num_tokens_to_revoke]
            index = @tokens_given[sender].indexOf recipient;
            @tokens_given[sender].splice index, 1 if index isnt -1;

            # remove the first occurence of sender in the list @tokens_received[recipient]
            index = @tokens_received[recipient].indexOf sender
            @tokens_received[recipient].splice index, 1 if index isnt -1

          if index isnt -1
            message = "#{sender_name} revoked " + num_tokens_to_revoke + " token" + (if num_tokens_to_revoke != 1 then "s" else "") + " from #{recipient_name}. "
            tokens_remaining = @max_tokens_per_user - @tokens_given[sender].length
            message += "#{sender_name} now has #{tokens_remaining} token" + (if tokens_remaining != 1 then "s" else "") + " remaining to give to others. "
            return message 


  # TODO: currently we're not using these functions. We're showing the same response every time.
  receive_token_response: ->
    @receive_token_responses[Math.floor(Math.random() * @receive_token_responses.length)]

  revoke_token_response: ->
    @revoke_token_responses[Math.floor(Math.random() * @revoke_token_responses.length)]

  selfDeniedResponses: (name) ->
    @self_denied_responses = [
      "Sorry #{name}. Tokens cannot be given to oneself.",
      "I can't do that #{name}. Tokens cannot be given to oneself.",
      "Tokens can only be given to other people."
    ]

  tally: (list_of_strings) -> 
    count = {}
    for x in list_of_strings
      if count[x]? then count[x] += 1 else count[x] = 1
    return count


  status: (id, self_bool) -> 
    # return the number of tokens remaining, number of tokens, and number of tokens received (including whom).
    # Inputs: 
    #  1. id is the ID of the user for which we'll return the status; 
    #  2. self_bool is a boolean variable for whether the person writing 
    #     this command is the same as the one for which we're returning the status
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

    # build up a string of results
    result = ""

    # number of tokens this person has left to give others
    tokens_remaining = @max_tokens_per_user - num_tokens_given

    has_have = if self_bool then "have " else "has "
    result += "#{name} " + has_have + (if tokens_remaining == @max_tokens_per_user then "all " else "") + tokens_remaining + " token" + (if tokens_remaining != 1 then "s" else "") + " remaining to give to others. "
    result += "\n"

    # number of tokens `name` has given to others (and to whom)
    if num_tokens_given > 0
      result += "#{name} " + has_have + "given " + num_tokens_given + " token" + (if num_tokens_given != 1 then "s" else "") + " to the following people: "
      #for own name_peer, number of @tally(tokens_given_by_this_person)
      #  result += "    - to #{name_peer}: #{number} token" + (if number != 1 then "s" else "") + "\n"
      result += ("@" + @robot.brain.userForId(id_peer).name + " (" + num_tokens.toString() + ")" for own id_peer, num_tokens of @tally(tokens_given_by_this_person)).join(", ")
    # else
    #   result += "#{name} has not given any tokens to other people. "
      result += "\n"


    # number of tokens `name` has received from others (and from whom)
    tokens_received_by_this_person = if @tokens_received[id]? then @tokens_received[id] else []
    num_tokens_received = tokens_received_by_this_person.length
    if num_tokens_received > 0
      result += "#{name} " + has_have + num_tokens_received + " token" + (if num_tokens_received != 1 then "s" else "") + " from the following people: "
      #for own name_peer, number of @tally(tokens_received_by_this_person)
      #  result += "    - from #{name_peer}: #{number} token" + (if number != 1 then "s" else "") + "\n"
      result += ("@" + @robot.brain.userForId(id_peer).name + " (" + num_tokens.toString() + ")" for own id_peer, num_tokens of @tally(tokens_received_by_this_person)).join(", ")
    else
      result += "#{name} " + (if self_bool then "do" else "does") + " not have any tokens from other people."

    #result += "\n\n Debugging: \n tokens_given_by_this_person = #{Util.inspect(tokens_given_by_this_person)} \n tokens_received_by_this_person = #{Util.inspect(tokens_received_by_this_person)}"

    return result

  leaderboard: (num_users) -> 
    user_num_tokens_received = ([@robot.brain.userForId(user_id).name, received_list.length] for own user_id, received_list of @tokens_received)

    if user_num_tokens_received.length == 0
      return "No one has received any tokens."



    # users = robot.brain.data._private
    # tuples = []
    # for username, score of users
    #   tuples.push([username, score])

    # if tuples.length == 0
    #   return "The lack of karma is too damn high!"

    # sort by the number of tokens received (in decreasing order)
    user_num_tokens_received.sort (a, b) ->
      if a[1] > b[1]
         return -1
      else if a[1] < b[1]
         return 1
      else
         return 0

    # build up a string `str` 
    limit = Math.min(num_users, user_num_tokens_received.length) #5
    str = "These #{limit} users have currently been thanked the most:\n"
    for i in [0...limit]
      username = user_num_tokens_received[i][0]
      points = user_num_tokens_received[i][1]
      point_label = if points == 1 then "token" else "tokens"
      leader = "" #if i == 0 then "All hail the supreme token holder!" else "" # label the one with the most
      newline = if i < limit - 1 then '\n' else ''
      str += "#{i+1}. @#{username} (#{points} " + point_label + ") " + leader + newline
    return str


######################################################################################################
######################################################################################################
######################################################################################################
######################################################################################################
######################################################################################################
######################################################################################################
######################################################################################################
######################################################################################################
######################################################################################################
######################################################################################################
######################################################################################################
######################################################################################################

# for inspecting an object usting Util.inspect
Util = require "util"

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

# alphabetic_number_alternatives = """
# zero|no|none|one|a|an|two|a couple of|a pair of|three|a few|four|five|a handful|several|
# six|a half dozen|seven|eight|nine|ten|eleven|twelve|a dozen|thirteen|a baker's dozen"""
alphabetic_number_alternatives = """
zero|no|none|one|a|an|two|three|four|five|several|
six|seven|eight|nine|ten|eleven|twelve|thirteen|some"""

fuzzy_string_to_nonnegative_int = (str) -> 
  if str.trim().search(/[0-9]+/i) != -1
    return parseInt(str, 10)
  else if str.search(/[a-z ]+/i) != -1
    return interpret_alphabetic_number str.trim()
  else
    return NaN

regexEscape = (str) ->
  return str.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&')


# the script must export a function. `robot` is an instance of the bot.
# we export a function of one variable, the `robot`, which `.hear`s messages and then does stuff
module.exports = (robot) ->
  tokenBot = new TokenNetwork robot

  ### 
    Environment variables
  ###

  # name of the bot 
  bot_name = process.env.HUBOT_ROCKETCHAT_BOTNAME or "token"
  bot_alias = process.env.HUBOT_ALIAS or "/"

  # whether tokens can be given or received. defaults to true
  tokens_can_be_given_or_revoked = if process.env.TOKENS_CAN_BE_TRANSFERRED? then stringToBool(process.env.TOKENS_CAN_BE_TRANSFERRED) else true #process.env.TOKENS_CAN_BE_TRANSFERRED #or true

  # whether people can give tokens to themself. defaults to false.
  allow_self = true #if process.env.TOKEN_ALLOW_SELF? then stringToBool(process.env.TOKEN_ALLOW_SELF) else false
  
  # default length for the leaderboard showing the people with the most tokens
  leaderboard_length = 10

  ###
    Give and revoke commands 
  ###

  give_regex_string = "give|send"#"\b(?:give|send)\b"
  give_regex = new RegExp("\\b(" + give_regex_string + ")\\b", "i")
  revoke_regex_string = "revoke|remove|rescind|cancel|void|retract|withdraw|take back|get back" #"\b(?:revoke|remove|rescind|cancel|void|retract|withdraw|take back|get back)\b"
  revoke_regex = new RegExp("\\b(" + revoke_regex_string + ")\\b", "i")
  number_regex_string = "[0-9]+" + "|" + alphabetic_number_alternatives
  number_regex = new RegExp(number_regex_string, "i")

  bot_alias_escaped = regexEscape bot_alias
  bot_name_escaped = regexEscape bot_name
  bot_name_regex_string = "\s*\b(?:" + bot_name_escaped + ":?\s*" + "|" + bot_alias_escaped + "\s*" + "|" + bot_name_escaped + ":?\s*" + bot_alias_escaped + ")\b"

  # debug
  #regex_test = "\b(give|send|revoke)\b(?:\s+\b([0-9]+|[a-zA-Z ]+)\b)?(?:\s+tokens{0,1})?(?:\s+\b(?:to|from)\b)?\s+@?([\w.\-]+)*\s*"
  regex_test = "\b(give|send|revoke)\b(?:\s+\b([0-9]+|[a-zA-Z ]+)\b)?(?:\s+tokens{0,1})?(?:\s+\b(?:to|from)\b)?\s+@?([\w.\-]+)\s*"

  give_revoke_regex_string = "" +
    "\\b(" + give_regex_string +        # give or revoke (first capturing group)
    "|" + revoke_regex_string + ")\\b" +  
    "(?:\\s+" +                         # number of tokens is optional (second capturing group)
    "\\b(" + number_regex_string + "|all" + ")\\b" + 
    ")?" +
    "(?:\\s+tokens{0,1})?" +            # token or tokens (optional)
    "(?:\\s+\\b(?:to|from)\\b)?" +        # to or from are optional
    "\\s+" +                            # at least 1 charachter of whitespace
    "@?([\\w.\\-]+)" +                  # user name or name (to be matched in a fuzzy way below) -- third capture group
    "\\s*$"                                # 0 or more whitespace

  give_revoke_regex = new RegExp(give_revoke_regex_string, "i")

  robot.respond give_revoke_regex, (res) ->  # `res` is an instance of Response. 
    sender = res.message.user
    sender_name = "@" + res.message.user.name
    sender_id = res.message.user.id

    # is the message a DM to the bot?
    # a message is a direct message if the message's room contains the sender_id 
    # (because the room ID is a concatenation of the IDs of the sender and recipients)
    is_direct_message = (res.message.room.indexOf(sender_id) > -1)

    #determine whether the user is trying to give a token or revoke a token
    if res.match[1].search(give_regex) != -1
      give_bool = true
    else if res.match[1].search(revoke_regex) != -1
      give_bool = false
    else
      # the command didn't match the regular expressions for giving nor for revoking 
      # this shouldn't fire because the command shouldn't match the regular expression `give_revoke_regex`
      # but we'll include this anyway just in case
      fail_message = "Sorry #{sender_name}, I couldn't understand your command."
      fail_message += " Type `#{bot_name} help` to see the list of commands."
      res.send fail_message
      return

    action_string = if give_bool then "give" else "revoke"

    # check whether the transferring tokens is frozen; 
    # if so, send a message and return
    if not tokens_can_be_given_or_revoked
      res.send "Sorry #{sender_name}, tokens can no longer be given nor revoked."
      robot.logger.info ("User {id: #{sender_id}, name: #{sender_name}} tried to " + 
                          action_string + 
                          " a token but tokens cannot be given now.")
      return
    
    # figure out who the recipient is 
    recipient_name_raw = res.match[3] # third capture group in give_revoke_regex
    recipients = robot.brain.usersForFuzzyName(recipient_name_raw.trim()) 
    
    # check whether we identified just one person with that user name
    # if not, send a failure message and return
    if recipients.length != 1
      fail_message = "Sorry #{sender_name}, I didn't understand that person ( `#{recipient_name_raw}` ) to whom you're trying to give a token."
      fail_message += "\n\nMake sure that you enter the person's user name correctly, either with or without a preceding @ symbol, such as `token give a token to @user_name`. "
      fail_message += "Also, if you did enter that person's user name correctly, I won't be able to give them a token from you until that person has sent at least one message in any channel."
      res.send fail_message
      return

    # now we know who the recipient is
    recipient = recipients[0]
    recipient_name = "@" + recipient.name
    recipient_id = recipient.id

    
    # check whether the sender is trying to give a token to himself/herself and allow_self is false
    # if so, return a random message saying that you can't give a token to yourself
    if not allow_self and res.message.user.id == recipient_id
      res.send res.random tokenBot.selfDeniedResponses(sender_name)
      robot.logger.info "User {id: #{sender_id}, name: #{sender_name}} tried to give himself/herself a token"
      return

    # figure out how many tokens they want to give or revoke
    # if the user doesn't provide a number, then assume that the number is 1
    num_tokens_to_transfer = switch
      when res.match[2] == "" or not res.match[2]? then 1
      when res.match[2] == "all" then tokenBot.max_tokens_per_user
      else fuzzy_string_to_nonnegative_int res.match[2]

    if num_tokens_to_transfer? and not isNaN num_tokens_to_transfer
      log_message = "{action: " + (if give_bool then "give" else "revoke") + ", "
      log_message += "sender: {id: #{sender_id}, name: #{sender_name}}, "
      log_message += "recipient: {id: #{recipient_id}, name: #{recipient_name}}, "
      log_message += "is_direct_message: #{is_direct_message}, "
      log_message += "numtokens: #{num_tokens_to_transfer}}"
      robot.logger.info log_message
      message = tokenBot.give_or_revoke_token sender_id, recipient_id, num_tokens_to_transfer, give_bool
      res.send message

      # if the command was givne in a direct message to the bot, 
      # then send a direct message to the recipient to notify them
      res.send "recipient: {id: #{recipient_id}, name: #{recipient_name}}"
      res.send "res.envelope = #{Util.inspect res.envelope}"
      res.send "res.envelope.user.name = #{res.envelope.user.name}"
      if is_direct_message
        robot.adapter.chatdriver.sendMessageByRoomId ("Psst. This action was done privately. " + message), robot.adapter.chatdriver.getDirectMessageRoomId(recipient_id).room
    else
      fail_message = "I didn't understand how many tokens you want to " + action_string + "."
      fail_message += " If you don't provide a number, I assume you want to " + action_string + " one token."
      fail_message += " I also understand numbers like 1, 2, 3 and some alphabetic numbers like one, two, three."
      res.send fail_message
    return

  ###
    Status and leaderboard commands 
  ###

  # respond to "status (of) @user"
  robot.respond ///            
                status           # "status"
                (?:\s+of)?       # "of" is optional
                \s+              # whitespace
                @?([\w.\-]+)   # user name or name (to be matched in a fuzzy way below). \w matches any word character (alphanumeric and underscore).
                \s*$             # 0 or more whitespace
                ///i, (res) ->

    name_raw = res.match[1]
    
    #if not name?
    #  res.send "Sorry, I couldn't understand the name you provided (#{name})."
    #else
    users = robot.brain.usersForFuzzyName(name_raw.trim()) # the second capture group is the user name


    if users.length == 1
      user = users[0]
      # whether the person writing the command is the one we're getting the status of
      self_bool = (user['id'] == res.message.user.id)
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
    "\\s+" +               # whitespace
    "(?:the\s+)?" +       # "the" is optional
    "top" +               # "top" is required
    "\\s+" +               # whitespace
    "(" + number_regex_string + ")" +       # length of leaderboard, such as "5" or "five"
    "(?:\\s+\\b(list|users|people)?\\b)?"  # "list" or "users" or "people" is optional
  
  show_top_n_regex = new RegExp(show_top_n_regex_string, "i")

  robot.respond show_top_n_regex, (res) -> 
    # grab the length of the leaderboard (the first capturing group)
    number_input = res.match[1]

    number_parseInt = switch
      when number_input == "" or not number_input? then leaderboard_length # default value
      when number_input == "all" then robot.brain.data.users.length
      else fuzzy_string_to_nonnegative_int number_input

    # if we can successfully parse number_input as a base-10 integer, 
    # then send the result of tokenBot.leaderboard
    if not isNaN number_parseInt
      if number_parseInt > 0
        res.sendPrivate tokenBot.leaderboard number_parseInt
      else
        res.sendPrivate "Please provide a positive integer; for example, use the command `#{bot_name} show top 5 list`."
    else
      # it's not an integer, so try to interpret an English word for a number
      number_interpreted = interpret_alphabetic_number number_input
      if isNaN number_interpreted
        res.sendPrivate "Sorry, I didn't understand the number you provided (` #{number_input} `). Use the command `#{bot_name} show leaderboard` to show the top #{leaderboard_length} list, or use `#{bot_name} show top n list` (where `n` is an integer) to show the `n` people who have received the most tokens."
      else
        res.sendPrivate tokenBot.leaderboard number_interpreted

  ###
    Miscellaneous commands
  ###

  # log all errors 
  robot.error (err, res) ->
    robot.logger.error "#{err}\n#{err.stack}"
    if res?
       res.reply "#{err}\n#{err.stack}"

  # inspect a user's user name
  robot.respond /inspect me/i, (res) ->
    user = robot.brain.userForId(res.message.user.id)
    res.send "#{Util.inspect(user)}"

  # show users, show all users -- show all users and their user names
  robot.respond /show (?:all )?users$/i, (res) ->
    res.sendPrivate "Here are all the users I know about: " + ("@#{user.name}" for own key, user of robot.brain.data.users).join ", "
    #res.send ("key: #{key}\tID: #{user.id}\tuser name:  @#{user.name}" for own key, user of robot.brain.data.users).join "\n"

  # show user with tokens still to give out to others
  robot.respond /\s*\b(show(?: the)? users \b(with|(?:who|that)(?: still)? have)\b tokens?|who(?: still)? has tokens?)(?: to give(?: out)?)?\??\s*/i, (res) ->
    # check whether tokenBot.tokens_given is empty
    if Object.keys(tokenBot.tokens_given).length == 0
      res.sendPrivate "No one has said anything yet, so I don't know of the existence of anyone yet!"
    else 
      response = ("@" + robot.brain.userForId(id).name + " (" + (tokenBot.max_tokens_per_user - recipients.length).toString() + " token" + (if tokenBot.max_tokens_per_user - recipients.length != 1 then "s" else "") + ")" for own id, recipients of tokenBot.tokens_given when recipients.length < tokenBot.max_tokens_per_user).join(", ")
      if response == "" # recipients.length == tokenBot.max_tokens_per_user for all users
        res.sendPrivate "Everyone has given out all their tokens."
      else
        res.sendPrivate "The following users still have tokens to give. Try to help these users so that they thank you with a token!\n" + response

  # if this is the first time that this user has said something, then add them to tokens_given and tokens_received
  robot.hear /.*/i, (res) -> 
    sender_id = res.message.user.id
    if tokenBot.tokens_given[sender_id]? == false # if @tokens_given[sender] has not yet been defined (i.e., it's null or undefined)
      tokenBot.tokens_given[sender_id] = []

    if tokenBot.tokens_received[sender_id]? == false
      tokenBot.tokens_received[sender_id] = []

  robot.respond /show robot.brain.data.users/i, (res) -> 
    res.send "#{Util.inspect(robot.brain.data.users)}"
    res.send "tokenBot.tokens_given = #{Util.inspect(tokenBot.tokens_given)}"
    res.send "tokenBot.tokens_received = #{Util.inspect(tokenBot.tokens_received)}"

  robot.respond /clear your brain/i, (res) -> 
    tokenBot.tokens_given = {}
    tokenBot.tokens_received = {}
    robot.brain.data.tokens_given = {}
    robot.brain.data.tokens_received = {}
    robot.brain.data.users = {}
    
  ###
    Help the user figure out how to use the bot
  ###
  robot.respond /what is your name\??/i, (res) -> 
    res.send "My name is #{bot_name}. You can give commands in the form `#{bot_name} <command>`."
    res.send "My ID is #{Util.inspect robot.brain.usersForFuzzyName(bot_name.trim())}"

  robot.hear /how do I \b(?:give|send)\b a token\??/i, (res) -> 
    res.send "Use the command `#{bot_name} give a token to @user_name`."

  robot.hear /how do I \b(?:revoke|get back)\b a token\??/i, (res) -> 
    res.send "Use the command `#{bot_name} revoke a token from @user_name`."

  # robot.hear /I like pie/i, (res) ->
  #     res.emote "makes a freshly baked pie"
  #     res.reply "makes a freshly baked pie"

