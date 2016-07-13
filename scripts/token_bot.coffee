# Description:
#   Track tokens given to acknowledge contributions from others
#
# Dependencies:
#   None
#
# Configuration:
#   TOKEN_ALLOW_SELF
#   TOKENS_CAN_BE_TRANSFERRED
#
# Commands:
#   hubot give (a) token (to) @user_name - gives a token to @user_name. 'a' and 'to' are optional.
#   hubot revoke (a) token (from) @user_name - revokes a token from @user_name. 'a' and 'from' are optional.
#   hubot token status (of) @user_name - check the status of @user_name's tokens (given and received). 'of' is optional.
#
# Environment variables:
#   TOKEN_ALLOW_SELF = false
#   TOKENS_CAN_BE_TRANSFERRED = true
#
# Author:
#   cbrummitt


## TODO: Update the commands list above. 
## From the scripting documentation: 
#####  At load time, Hubot looks at the Commands section of each scripts, and build a list of all commands. 
##### The included help.coffee lets a user ask for help across all commands, or with a search. 
##### Refer to the Hubot as hubot, even if your hubot is named something else. It will automatically be replaced with the correct name. This makes it easier to share scripts without having to update docs.


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
    
    # each user can give at most this many tokens to others
    # TODO: make this an environment variable? See `allow_self = process.env.KARMA_ALLOW_SELF or "true"` in the karma bot
    @max_tokens_per_user = 5 

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

      return "#{sender} gave one token to #{recipient}.\n#{recipient} has received tokens from the following: #{@tokens_received[recipient]}."
    else
      return "#{sender}: you do not have any more tokens available to give to others. If you want, revoke a token using the command `revoke @user_name`."

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
      return "#{sender} has not given tokens to anyone, so I cannot revoke any tokens. Give tokens using the command `token give token @user_name`."
    else if not @tokens_received[recipient] # TODO: should this check whether recipient is in @tokens_given[sender]? right now this is checked by the `splice` code below 
      return "#{recipient} has not received any tokens from anyone." #"#{sender} has not given any tokens to #{recipient}."
    else # sender has sent >=1 token to someone, and recipieint has received >=1 token from someone
      
      # remove the first occurrence of recipient in the list @tokens_given[sender]
      index = @tokens_given[sender].indexOf recipient
      @tokens_given[sender].splice index, 1 if index isnt -1

      # remove the first occurence of sender in the list @tokens_received[recipient]
      index = @tokens_received[recipient].indexOf sender
      @tokens_received[recipient].splice index, 1 if index isnt -1

      if index isnt -1
        return "#{sender} revoked one token from #{recipient}."
      else
        return "#{sender}: #{recipient} does not have any tokens from you, so you cannot revoke a token from #{recipient}."

  # TODO: currently we're not using these functions. We're showing the same response every time.
  receive_token_response: ->
    @receive_token_responses[Math.floor(Math.random() * @receive_token_responses.length)]

  revoke_token_response: ->
    @revoke_token_responses[Math.floor(Math.random() * @revoke_token_responses.length)]

  selfDeniedResponses: (name) ->
    @self_denied_responses = [
      "Sorry #{name}. Tokens cannot be given to oneself.",
      "I can't do that #{name}.",
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
    result += "#{name} has " + tokens_remaining + " token" + (if tokens_remaining != 1 then "s" else "") + " remaining to give to others. "
    result += "\n\n"

    # number of tokens `name` has given to others (and to whom)
    if num_tokens_given > 0
      result += "#{name} has given " + num_tokens_given + " token" + (if num_tokens_given != 1 then "s" else "") + " to the following people:\n"
      for own name, number of @tally(tokens_given_by_this_person)
        result += "    - #{name}: #{number} token" + (if number != 1 then "s" else "") + "\n"
    else
      result += "#{name} has not given any tokens to other people. "
    result += "\n\n"


    # number of tokens `name` has received from others (and from whom)
    tokens_received_by_this_person = if @tokens_received[name]? then @tokens_received[name] else []
    num_tokens_received = tokens_received_by_this_person.length
    if num_tokens_received > 0
      result += "#{name} has received " + num_tokens_received + " token" + (if num_tokens_received != 1 then "s" else "") + " from the following people:\n"
      for own name, number of @tally(tokens_received_by_this_person)
        result += "    - #{name}: #{number} token" + (if number != 1 then "s" else "") + "\n"
    else
      result += "#{name} has not received any tokens from other people."

    result += "\n\n Debugging: \n tokens_given_by_this_person = #{Util.inspect(tokens_given_by_this_person)} \n tokens_received_by_this_person = #{Util.inspect(tokens_received_by_this_person)}"

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


# the script must export a function. `robot` is an instance of the bot.
# we export a function of one variable, the `robot`, which `.hear`s messages and then does stuff
module.exports = (robot) ->
  tokenBot = new TokenNetwork robot

  verbose = false

  # name of the bot 
  bot_name = process.env.HUBOT_ROCKETCHAT_BOTNAME

  # whether tokens can be given or received
  # defaults to true
  #tokens_can_be_given_or_revoked = process.env.TOKENS_CAN_BE_TRANSFERRED #or true

  # environment variables
  allow_self = process.env.TOKEN_ALLOW_SELF #or false # whether someone can give a token to himself

  # three responses for testing purposes only (will remove these later)
  robot.respond /test/ig, (res) -> 
    res.send "responding to `test`"

  robot.respond /what is your name\?/, (res) -> 
    res.send "My name is #{bot_name}. You can give commands in the form `#{bot_name} command`."

  robot.hear /badger/i, (res) ->
    res.send "Badgers? BADGERS? WE DON'T NEED NO STINKIN BADGERS!123"


  ###
    Give and revoke commands 
  ###

  ## respond to `give a token @user_name`
  robot.respond ///
                (give|send)         # give or send
                (\sa)?              # a is optional
                \stokens{0,1}       # token or tokens
                (\sto)?             # to is optional
                \s                  # 1 charachter of whitespace
                @?([\w .\-]+)*      # user name or name (to be matched in a fuzzy way below)
                \s*$                # 0 or more whitespace
               ///, (res) ->       # `res` is an instance of Response. 
    
    sender = res.message.user.name

    if process.env.TOKENS_CAN_BE_TRANSFERRED == false or process.env.TOKENS_CAN_BE_TRANSFERRED == "false" #not process.env.TOKENS_CAN_BE_TRANSFERRED
      res.send "Sorry #{sender}, tokens can no longer be given nor revoked."
      robot.logger.info "#{sender} tried to give a token but tokens cannot be given now."
    else 
      # figure out who the recipient is 
      recipients = robot.brain.usersForFuzzyName(res.match[4].trim()) # the fourth capture group is the name of the recipient
      ## TODO: does this handle errors with the name not a username? 
      ## TODO: what does this command do if I give it "/give token xxx" where "xxx" isn't the name of a user?
      
      #if not (recipients.length >= 1) # I don't think this will every occur.
      #  res.send "Sorry, I didn't understand that user name #{res.match[4]}."
      #else

      res.send "\n************ BEGIN information for debugging ************"
      res.send "The command `give a token` fired. The sender is #{sender}. res.match[4] = #{res.match[4]}."
      res.send "The value of process.env.TOKENS_CAN_BE_TRANSFERRED is #{process.env.TOKENS_CAN_BE_TRANSFERRED}"
      res.send "robot.brain.usersForFuzzyName(res.match[4].trim()) = recipients = #{recipients}"
      res.send "Util.inspect(recipients) = #{Util.inspect(recipients)}. Util.inspect(recipients[0]) = #{Util.inspect(recipients[0])}. " 

      res.send "robot.brain.userForName(res.match[4].trim()) = #{robot.brain.userForName(res.match[4].trim())}. Contents: #{Util.inspect(robot.brain.userForName(res.match[4].trim()))}"
      res.send "robot.brain.usersForRawFuzzyName(res.match[4].trim()) = #{robot.brain.usersForRawFuzzyName(res.match[4].trim())}. Contents: #{Util.inspect(robot.brain.usersForRawFuzzyName(res.match[4].trim()))}"
      res.send "************ END information for debugging ************\n"

      if recipients.length == 1
        recipient = recipients[0]['name']

        if allow_self is true or res.message.user.name != recipient
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
        res.send "Sorry #{sender}, I didn't understand to whom you're trying to give a token."


  ## respond to `revoke (a) token (from) @user_name`
  robot.respond ///
                (revoke|remove)     # revoke or remove
                (\sa)?              # a is optional
                \stokens{0,1}       # token or tokens
                (\sfrom)?           # from is optional
                \s                  # 1 charachter of whitespace
                @?([\w .\-]+)*      # user name or name (to be matched in a fuzzy way below)
                \s*$                # 0 or more whitespace
                ///, (res) ->       # `res` is an instance of Response. 
    
    sender = res.message.user.name # the user name of the person who is revoking a token from someone else

    if process.env.TOKENS_CAN_BE_TRANSFERRED == false or process.env.TOKENS_CAN_BE_TRANSFERRED == "false" #not process.env.TOKENS_CAN_BE_TRANSFERRED
      res.send "Sorry #{sender}, tokens can no longer be given nor revoked."
      robot.logger.info "#{sender} tried to revoke a token but tokens cannot be given now."
    else 
      # figure out who the recipient (person losing a token) is 
      recipients = robot.brain.usersForFuzzyName(res.match[4].trim()) # the fourth capture group is the name of the recipient
      ## TODO: does this handle errors with the name not a username? 
      ## TODO: what does this command do if I give it "/revoke token xxx" where "xxx" isn't the name of a user?
      
      res.send "\n************ BEGIN information for debugging ************"
      res.send "The command `revoke a token` fired. The sender is #{sender}. res.match[4] = #{res.match[4]}."
      res.send "The value of process.env.TOKENS_CAN_BE_TRANSFERRED is #{process.env.TOKENS_CAN_BE_TRANSFERRED}"
      res.send "robot.brain.usersForFuzzyName(res.match[4].trim()) = recipients = #{recipients}"
      res.send "Util.inspect(recipients) = #{Util.inspect(recipients)}. Util.inspect(recipients[0]) = #{Util.inspect(recipients[0])}. " 
      res.send "************ BEGIN information for debugging ************\n"

      #if not (recipients.length >= 1) # I don't think this will every occur.
      #  res.send "Sorry, I didn't understand that user name #{res.match[4]}."
      #else
      if recipients.length == 1
        recipient = recipients[0]['name']

        message = tokenBot.revoke_token sender, recipient
        robot.logger.info "#{sender} revoked a token from #{recipient}"
        res.send message
      else
        res.send "Sorry #{sender}, I didn't understand from whom you're trying to revoke a token."

  ###
    Status commands 
  ###

  # respond to "status (of) @user"
  robot.respond ///            
                status           # "status"
                (\sof)?          # "of" is optional
                \s               # whitespace
                @?([\w .\-]+)*   # user name or name (to be matched in a fuzzy way below). \w matches any word character (alphanumeric and underscore).
                \s*$             # 0 or more whitespace
                ///i, (res) ->

    # for debugging: 

    name = res.match[2]
    
    res.send "the command `status (of) @user` fired; the name provided is #{name}"

    if not name?
      res.send "Sorry, I couldn't understand the name you provided, which was #{name}."
    else
      users = robot.brain.usersForFuzzyName(name.trim()) # the second capture group is the user name

      res.send "Util.inspect(users) = #{Util.inspect(users)}\n" 
      # if not (users.length >= 1)
      #   res.send "Sorry, I didn't understand that user name #{name}."
      # else
      #   user = users[0]
      #   res.send tokenBot.status user
      if users.length == 1
        user = users[0]
        #res.send "User = #{user}. User['name'] = #{user['name']}. User['id'] = #{user['id']}."
        res.send tokenBot.status user['name']

  # Listen for the command `status` without any user name provided.
  # This sends the message returned by `tokenBot.status` on the input `res.message.user.name`.
  robot.respond /status$/, (res) ->
    # for debugging: 
    res.send "the command `status` (without a user name provided) fired"
    res.send tokenBot.status res.message.user.name


  # log all errors 
  robot.error (err, res) ->
    robot.logger.error "#{err}\n#{err.stack}"
    if res?
       res.reply "#{err}\n#{err.stack}"

  # inspect a user's user name
  robot.respond /hi robot/i, (res) ->
    user = robot.brain.usersForFuzzyName(res.message.user.name)
    res.send "#{Util.inspect(user)}"

  # show all users and their user names (and email addresses if they've provided one)
  robot.respond /show users$/i, (msg) ->
    response = ""

    for own key, user of robot.brain.data.users
      response += "ID: #{user.id}\t\tuser name:  #{user.name}"
      response += " <#{user.email_address}>" if user.email_address
      response += "\n"
    msg.send response

