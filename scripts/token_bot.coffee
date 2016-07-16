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
#   hubot give a token to @user_name - Gives a token to `@user_name`. 'a' and 'to' are optional.
#   hubot revoke a token from @user_name` - Revokes a token from `@user_name`. 'a' and 'from' are optional.
#   hubot token status of @user_name - Returns the status of `@user_name`'s tokens. 'of' is optional.
#   hubot show all users - Returns a list of all the users that the bot knows about. 'all' is optional.
#   hubot who has tokens to give? - Returns a list of all users who still have tokens to give out. Try to help these users so that they thank you with a token!
#   hubot show users with tokens - Returns a list of all users who still have tokens to give out. Try to help these users so that they thank you with a token!
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
      @tokens_given[user['name']] = 0
      @tokens_received[user['name']] = 0
    
    # each user can give at most this many tokens to others
    # TODO: make this an environment variable? See `allow_self = process.env.KARMA_ALLOW_SELF or "true"` in the karma bot
    @max_tokens_per_user = process.env.TOKENS_ENDOWED_TO_EACH_USER or 5 

    # variable that determines whether tokens can be given right now
    # TDOO: write a method that will turn this off and display a message in #general telling everyone that tokens can no longer be given?
    # TODO: make these environment variables ` ... = process.env.HUBOT_CAN_TRANSFER_TOKENS or true`
    #@tokens_can_be_given = true
    #@tokens_can_be_revoked = true

    # list of responses to display when someone receives or gives a token
    @receive_token_responses = ["received a token!", "was thanked with a token!"]
    @revoke_token_responses = ["lost a token :(", "had a token revoked"]

    # if the brain was already on, then set the cache to the dictionary @robot.brain.data.tokens_given
    # the fat arrow `=>` binds the current value of `this` (i.e., `@`) on the spot

    # do we want to use this snippet? https://github.com/github/hubot/issues/880#issuecomment-81386478
    @robot.brain.on 'loaded', =>
      if @robot.brain.data.tokens_given
        @tokens_given = @robot.brain.data.tokens_given
      if @robot.brain.data.tokens_received
        @tokens_received = @robot.brain.data.tokens_received


  #### Methods ####

  # TODO: remove this command `freeze_tokens` once we migrate to using the environment variable TOKENS_CAN_BE_TRANSFERRED
  #freeze_tokens: (allow_tokens_to_be_sent_or_received) -> 
  #  @tokens_can_be_given = allow_tokens_to_be_sent_or_received
  #  @tokens_can_be_revoked = allow_tokens_to_be_sent_or_received

  give_token: (sender, recipient) -> 
    # `give_token` gives a token from the sender to recipient. It returns a message to send to the chat channel.
    # we know that tokens can be given (i.e., process.env.TOKENS_CAN_BE_TRANSFERRED == 'true') because that's handled by the response.

    # check whether @cacheTokens[sender] exists and if not set it to []
    if @tokens_given[sender]? == false # if @tokens_given[sender] has not yet been defined (i.e., it's null or undefined)
      @tokens_given[sender] = []
      #robot.brain.set sender, 'sent', ['test']
      #return "robot.brain.get sender, 'sent' = #{robot.brain.get sender, 'sent', ['test']}"

    if @tokens_received[recipient]? == false
      @tokens_received[recipient] = []

    # if the sender has not already given out more that `@max_tokens_per_user` tokens, then add recepient to @cacheTokens[sender]'s list.
    # note that this allows someone to send multiple tokens to the same user
    if @tokens_given[sender].length < @max_tokens_per_user
      # update @tokens_given 
      @tokens_given[sender].push recipient
      @robot.brain.data.tokens_given = @tokens_given

      # update @tokens_received
      @tokens_received[recipient].push sender
      @robot.brain.data.tokens_received = @tokens_received

      message = "@#{sender} gave one token to @#{recipient}. " 
      tokens_remaining = @max_tokens_per_user - @tokens_given[sender].length
      message += "@#{sender} now has #{tokens_remaining} token" + (if tokens_remaining != 1 then "s" else "") + " remaining to give to others. "

      return message 
      #message += "\n#{recipient} has received tokens from the following: " # #{@tokens_received[recipient]}."
      #for own name_peer, number of @tally(@tokens_received[recipient])
      #  result += "#{name_peer} (#{number} token" + (if number != 1 then "s" else "") + ") "
      #result += (name_peer + " (" + num_tokens.toString() + ")" for own name_peer, num_tokens of @tally(@tokens_received[recipient])).join(", ")
    else
      return "@#{sender}: you do not have any more tokens available to give to others. If you want, revoke a token using the command `token revoke a token from @user_name`."

  revoke_token: (sender, recipient) ->
    # `revoke_token` removes recipient from @tokens_given[sender] and removes sender from @tokens_received[recipient] 
    # note that if the sender has given >1 token to recipient, this will remove just one of those tokens from the recipient.
    # we know that tokens can be given (i.e., process.env.TOKENS_CAN_BE_TRANSFERRED == 'true') because that's handled by the response.

    # # first check whether @tokens_can_be_revoked == false; if so, then return with a message.
    # if not process.env.TOKENS_CAN_BE_TRANSFERRED #@tokens_can_be_revoked
    #   return "Sorry #{sender}, tokens can no longer be given nor revoked."
    # else  

    # check whether @tokens_given[sender] or @tokens_received[recipient] is null or undefined
    if not @tokens_given[sender]?
      return "@#{sender} has not given tokens to anyone, so I cannot revoke any tokens. Give tokens using the command `token give token @user_name`."
    else if not @tokens_received[recipient]
      return "@#{recipient} has not received any tokens from anyone." #"#{sender} has not given any tokens to #{recipient}."
    else # sender has sent >=1 token to someone, and recipieint has received >=1 token from someone
      
      # remove the first occurrence of recipient in the list @tokens_given[sender]
      index = @tokens_given[sender].indexOf recipient
      @tokens_given[sender].splice index, 1 if index isnt -1

      # remove the first occurence of sender in the list @tokens_received[recipient]
      index = @tokens_received[recipient].indexOf sender
      @tokens_received[recipient].splice index, 1 if index isnt -1

      if index isnt -1
        message = "@#{sender} revoked one token from @#{recipient}. "
        tokens_remaining = @max_tokens_per_user - @tokens_given[sender].length
        message += "@#{sender} now has #{tokens_remaining} token" + (if tokens_remaining != 1 then "s" else "") + " remaining to give to others. "
        return message 
      else
        return "@#{sender}: @#{recipient} does not have any tokens from you, so you cannot revoke a token from @#{recipient}."

  # TODO: currently we're not using these functions. We're showing the same response every time.
  receive_token_response: ->
    @receive_token_responses[Math.floor(Math.random() * @receive_token_responses.length)]

  revoke_token_response: ->
    @revoke_token_responses[Math.floor(Math.random() * @revoke_token_responses.length)]

  selfDeniedResponses: (name) ->
    @self_denied_responses = [
      "Sorry @#{name}. Tokens cannot be given to oneself.",
      "I can't do that @#{name}.",
      "Tokens can only be given to other people."
    ]

  tally: (list_of_strings) -> 
    count = {}
    for x in list_of_strings
      if count[x]? then count[x] += 1 else count[x] = 1
    return count


  status: (name) -> 
    # return the number of tokens remaining, number of tokens, and number of tokens received (including whom).
    # Example:
    # @name has 2 tokens remaining to give to others. 
    # @name has given tokens to the following people: 
    #   @user_4 (1 token)
    #   @user_8 (2 tokens) 
    # @name has received 2 tokens from others: 
    #   @user_4 (1 token)
    #   @user_5 (1 token)


    # list of the people to whom `name` has given tokens
    tokens_given_by_this_person = if @tokens_given[name]? then @tokens_given[name] else []
    num_tokens_given = tokens_given_by_this_person.length

    # build up a string of results
    result = ""

    # number of tokens this person has left to give others
    tokens_remaining = @max_tokens_per_user - num_tokens_given
    result += "@#{name} has " + tokens_remaining + " token" + (if tokens_remaining != 1 then "s" else "") + " remaining to give to others. "
    result += "\n"

    # number of tokens `name` has given to others (and to whom)
    if num_tokens_given > 0
      result += "@#{name} has given " + num_tokens_given + " token" + (if num_tokens_given != 1 then "s" else "") + " to the following people: "
      #for own name_peer, number of @tally(tokens_given_by_this_person)
      #  result += "    - to #{name_peer}: #{number} token" + (if number != 1 then "s" else "") + "\n"
      result += ("@" + name_peer + " (" + num_tokens.toString() + ")" for own name_peer, num_tokens of @tally(tokens_given_by_this_person)).join(", ")
    else
      result += "@#{name} has not given any tokens to other people. "
    result += "\n"


    # number of tokens `name` has received from others (and from whom)
    tokens_received_by_this_person = if @tokens_received[name]? then @tokens_received[name] else []
    num_tokens_received = tokens_received_by_this_person.length
    if num_tokens_received > 0
      result += "@#{name} has received " + num_tokens_received + " token" + (if num_tokens_received != 1 then "s" else "") + " from the following people: "
      #for own name_peer, number of @tally(tokens_received_by_this_person)
      #  result += "    - from #{name_peer}: #{number} token" + (if number != 1 then "s" else "") + "\n"
      result += ("@" + name_peer + " (" + num_tokens.toString() + ")" for own name_peer, num_tokens of @tally(tokens_received_by_this_person)).join(", ")
    else
      result += "@#{name} has not received any tokens from other people."

    #result += "\n\n Debugging: \n tokens_given_by_this_person = #{Util.inspect(tokens_given_by_this_person)} \n tokens_received_by_this_person = #{Util.inspect(tokens_received_by_this_person)}"

    return result


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

# for inspecting an object
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


# the script must export a function. `robot` is an instance of the bot.
# we export a function of one variable, the `robot`, which `.hear`s messages and then does stuff
module.exports = (robot) ->
  tokenBot = new TokenNetwork robot

  # name of the bot 
  bot_name = process.env.HUBOT_ROCKETCHAT_BOTNAME

  # whether tokens can be given or received. defaults to true
  tokens_can_be_given_or_revoked = if process.env.TOKENS_CAN_BE_TRANSFERRED? then stringToBool(process.env.TOKENS_CAN_BE_TRANSFERRED) else true #process.env.TOKENS_CAN_BE_TRANSFERRED #or true

  # whether people can give tokens to themself. defaults to false.
  allow_self = if process.env.TOKEN_ALLOW_SELF? then stringToBool(process.env.TOKEN_ALLOW_SELF) else false
  # environment variables


  # robot.hear /badger/i, (res) ->
  #   res.send "Badgers? BADGERS? WE DON'T NEED NO STINKIN BADGERS!123"


  ###
    Give and revoke commands 
  ###

  ## respond to `give a token @user_name`
  robot.respond ///
                \b(?:give|send)\b         # give or send
                (?:\s+a)?              # a is optional
                (?:\s+tokens{0,1})?       # token or tokens
                (?:\s+to)?             # to is optional
                \s+                  # 1 charachter of whitespace
                @?([\w.\-]+)*      # user name or name (to be matched in a fuzzy way below)
                \s*$                # 0 or more whitespace
               ///i, (res) ->       # `res` is an instance of Response. 
    
    sender = res.message.user.name

    if not tokens_can_be_given_or_revoked
      res.send "Sorry @#{sender}, tokens can no longer be given nor revoked."
      robot.logger.info "#{sender} tried to give a token but tokens cannot be given now."
    else 
      # figure out who the recipient is 
      recipient_name_raw = res.match[1]# the fourth capture group is the name of the recipient
      recipients = robot.brain.usersForFuzzyName(recipient_name_raw.trim()) 
      ## TODO: does this handle errors with the name not a username? 
      ## TODO: what does this command do if I give it "/give token xxx" where "xxx" isn't the name of a user?
      
      #if not (recipients.length >= 1) # I don't think this will every occur.
      #  res.send "Sorry, I didn't understand that user name #{res.match[4]}."
      #else

      # res.send "\n************ BEGIN information for debugging ************"
      # res.send "The command `give a token` fired. The sender is #{sender}. res.match[4] = #{res.match[4]}."
      # res.send "The value of process.env.TOKENS_CAN_BE_TRANSFERRED is #{process.env.TOKENS_CAN_BE_TRANSFERRED}. The value of tokens_can_be_given_or_revoked is #{tokens_can_be_given_or_revoked}."
      # res.send "robot.brain.usersForFuzzyName(res.match[4].trim()) = recipients = #{recipients}"
      # res.send "Util.inspect(recipients) = #{Util.inspect(recipients)}. Util.inspect(recipients[0]) = #{Util.inspect(recipients[0])}. " 

      # res.send "robot.brain.userForName(res.match[4].trim()) = #{robot.brain.userForName(res.match[4].trim())}. Contents: #{Util.inspect(robot.brain.userForName(res.match[4].trim()))}"
      # res.send "robot.brain.usersForRawFuzzyName(res.match[4].trim()) = #{robot.brain.usersForRawFuzzyName(res.match[4].trim())}. Contents: #{Util.inspect(robot.brain.usersForRawFuzzyName(res.match[4].trim()))}"
      # res.send "************ END information for debugging ************\n"

      if recipients.length == 1
        recipient = recipients[0]['name'] # TODO: does this need to be the ID rather than name so that we are sure we don't have conflicting names?

        if allow_self or res.message.user.name != recipient 
          robot.logger.info "#{sender} sent a token to #{recipient}"
          message = tokenBot.give_token sender, recipient
          res.send message
          #karma.increment subject
          #msg.send "#{subject} #{karma.incrementResponse()} (Karma: #{karma.get(subject)})"
        else
          # allow_self is false and res.message.user.name == recipient, 
          # so return a random message saying that you can't give a token to yourself
          res.send res.random tokenBot.selfDeniedResponses(res.message.user.name)
          robot.logger.info "#{sender} tried to give himself/herself a token"
      else
        fail_message = "Sorry @#{sender}, I didn't understand that person ( `#{recipient_name_raw}` ) to whom you're trying to give a token."
        fail_message += "\n\nMake sure that you enter the person's user name correctly, either with or without a preceding @ symbol, such as `token give a token to @user_name`. "
        fail_message += "Also, if you did enter that person's user name correctly, I won't be able to give them a token from you until that person has sent at least one message in any channel."
        res.send fail_message

  ## respond to `revoke (a) token (from) @user_name`
  robot.respond ///
                \b(?:revoke|remove)\b     # revoke or remove
                (?:\s+a)?           # a is optional
                (?:\s+tokens{0,1})?   # token or tokens
                (?:\s+from)?          # from is optional
                \s+                 # at least 1 charachter of whitespace
                @?([\w.\-]+)*      # user name or name (to be matched in a fuzzy way below)
                \s*$                # 0 or more whitespace
                ///i, (res) ->       # `res` is an instance of Response. 
    
    sender = res.message.user.name # the user name of the person who is revoking a token from someone else

    if not tokens_can_be_given_or_revoked
      res.send "Sorry @#{sender}, tokens can no longer be given nor revoked."
      robot.logger.info "@#{sender} tried to revoke a token but tokens cannot be given now."
    else 
      # figure out who the recipient (person losing a token) is 
      recipient_name_raw = res.match[1] # the first capture group is the name of the recipient

      recipients = robot.brain.usersForFuzzyName(recipient_name_raw.trim()) 
      
      ## TODO: does this handle errors with the name not a username? 
      ## TODO: what does this command do if I give it "/revoke token xxx" where "xxx" isn't the name of a user?
      
      # Debug messages:
      # res.send "\n************ BEGIN information for debugging ************"
      # res.send "The command `revoke a token` fired. The sender is #{sender}. res.match[4] = #{res.match[4]}."
      # res.send "The value of process.env.TOKENS_CAN_BE_TRANSFERRED is #{process.env.TOKENS_CAN_BE_TRANSFERRED}. The value of tokens_can_be_given_or_revoked is #{tokens_can_be_given_or_revoked}."
      # res.send "robot.brain.usersForFuzzyName(res.match[4].trim()) = recipients = #{recipients}"
      # res.send "Util.inspect(recipients) = #{Util.inspect(recipients)}. Util.inspect(recipients[0]) = #{Util.inspect(recipients[0])}. " 
      # res.send "************ BEGIN information for debugging ************\n"

      #if not (recipients.length >= 1) # I don't think this will every occur.
      #  res.send "Sorry, I didn't understand that user name #{res.match[4]}."
      #else
      if recipients.length == 1
        recipient = recipients[0]['name']

        message = tokenBot.revoke_token sender, recipient
        robot.logger.info "#{sender} revoked a token from #{recipient}"
        res.send message
      else
        #res.send "Sorry #{sender}, I didn't understand from whom you're trying to revoke a token."
        fail_message = "Sorry @#{sender}, I didn't understand that person ( `#{recipient_name_raw}` ) from whom you're trying to revoke a token."
        fail_message += "\n\nMake sure that you enter the person's user name correctly, either with or without a preceding @ symbol, such as , such as `token revoke a token from @user_name`. "
        # we must know about that recipient in order to give them a token in the first place, so the commented-out message below isn't needed
        #fail_message += "Also, if you did enter that person's user name correctly, I won't be able to give them a token from you until that person has sent at least one message in any channel."
        res.send fail_message

  # send a response if people try to send or revoke tokens to/from multiple people
  robot.respond ///
                \b(revoke|remove|give|send)\b
                (\s+a)?
                (\s+tokens{0,1})?
                (\s+to|from)?
                (?:\s+(?!from|to)@?([\w.\-]+)){2,} # at least two user names; this part cannot match `to` nor `from`
                \s*$///, (res) -> 
    res.send "Please send or revoke only one token at a time. Rather than using first and last names, please use user names, which do not have any spaces."


  ###
    Status commands 
  ###

  # respond to "status (of) @user"
  robot.respond ///            
                status           # "status"
                (?:\s+of)?       # "of" is optional
                \s+              # whitespace
                @?([\w.\-]+)   # user name or name (to be matched in a fuzzy way below). \w matches any word character (alphanumeric and underscore).
                \s*$             # 0 or more whitespace
                ///i, (res) ->

    name = res.match[1]
    
    #if not name?
    #  res.send "Sorry, I couldn't understand the name you provided (#{name})."
    #else
    users = robot.brain.usersForFuzzyName(name.trim()) # the second capture group is the user name


    if users.length == 1
      user = users[0]
      res.send tokenBot.status user['name']
    else
      res.send "Sorry, I couldn't understand the name you provided ( `#{name}` )."

  # Listen for the command `status` without any user name provided.
  # This sends the message returned by `tokenBot.status` on the input `res.message.user.name`.
  robot.respond ///
                \s*
                status
                \s*
                ///i, (res) ->
    res.send tokenBot.status res.message.user.name


  # log all errors 
  robot.error (err, res) ->
    robot.logger.error "#{err}\n#{err.stack}"
    if res?
       res.reply "#{err}\n#{err.stack}"

  # inspect a user's user name
  robot.respond /inspect me/i, (res) ->
    user = robot.brain.usersForFuzzyName(res.message.user.name)
    res.send "#{Util.inspect(user)}"

  # show users, show all users -- show all users and their user names
  robot.respond /show (?:all )?users$/i, (res) ->
    res.send ("key: #{key}\tID: #{user.id}\tuser name:  @#{user.name}" for own key, user of robot.brain.data.users).join "\n"

  #robot.hear /.*/i, (res) -> 
  #  res.send "Someone said something!" 

  robot.respond /show robot.brain.data.users/i, (res) -> 
    res.send "#{Util.inspect(robot.brain.data.users)}"
    res.send "tokenBot.tokens_given = #{Util.inspect(tokenBot.tokens_given)}"
    res.send "tokenBot.tokens_received = #{Util.inspect(tokenBot.tokens_received)}"

  # show all users and their user names (and email addresses if they've provided one)
  robot.respond /\s*\b(show(?: the)? users \b(with|(?:who|that)(?: still)? have)\b tokens|who(?: still)? has tokens)(?: to give(?: out)?)?\??\s*/i, (res) ->
    # check whether tokenBot.tokens_given is empty
    if Object.keys(tokenBot.tokens_given).length == 0
      res.send "No one has said anything yet, so I don't know of the existence of anyone yet!"
    else 
      response = ("@" + name + " (" + (tokenBot.max_tokens_per_user - recipients.length).toString() + " token" + (if tokenBot.max_tokens_per_user - recipients.length != 1 then "s" else "") + ")" for own name, recipients of tokenBot.tokens_given when recipients.length < tokenBot.max_tokens_per_user).join(", ")
      if response == "" # recipients.length == tokenBot.max_tokens_per_user for all users
        res.send "Everyone has given out all their tokens."
      else
        res.send "The following users still have tokens to give. Try to help these users so that they thank you with a token!\n" + response
  
  ###
    Help the user figure out how to use the bot
  ###
  robot.respond /what is your name\??/i, (res) -> 
    res.send "My name is #{bot_name}. You can give commands in the form `#{bot_name} <command>`."

  robot.hear /how do I \b(?:give|send)\b a token\??/i, (res) -> 
    res.send "Use the command `#{bot_name} give a token to @user_name`."

  robot.hear /how do I \b(?:revoke|get back)\b a token\??/i, (res) -> 
    res.send "Use the command `#{bot_name} revoke a token from @user_name`."


