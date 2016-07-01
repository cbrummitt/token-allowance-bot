# Description:
#   Track tokens given to acknowledge contributions from others
#
# Dependencies:
#   None
#
# Configuration:
#   TOKEN_ALLOW_SELF
#
# Commands:
#   <thing>++ - give thing some karma
#   <thing>-- - take away some of thing's karma
#   hubot karma <thing> - check thing's karma (if <thing> is omitted, show the top 5)
#   hubot karma empty <thing> - empty a thing's karma
#   hubot karma best - show the top 5
#   hubot karma worst - show the bottom 5
#
# Author:
#   cbrummitt


# ##### begin Charlie's code #######

# Environment variables:
#   TOKEN_ALLOW_SELF = false

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
    @tokens_can_be_given = true
    @tokens_can_be_revoked = true

    # list of responses to display when someone receives or gives a token
    @receive_token_responses = ["received a token!", "was thanked with a token!"]
    @revoke_token_responses = ["lost a token :(", "had a token revoked"]

    # if the brain was already on, then set the cache to the dictionary @robot.brain.data.tokens_given
    # the fat arrow `=>` binds the current value of `this` (i.e., `@`) on the spot
    @robot.brain.on 'loaded', =>
      if @robot.brain.data.tokens_given
        @tokens_given = @robot.brain.data.tokens_given


  #### Methods ####

  give_token: (sender, recipient) -> 
    # check whether tokens can be given. Returns a message to send to the chat channel.
    # TODO: do this in the method that listens for the command? If @tokens_can_be_given is false, then we should display the message `Tokens can no longer be given.`
    if @tokens_can_be_given

      # check whether @cacheTokens[sender] exists and if not set it to []
      @tokens_given[sender] ?= []

      # if the sender has not already given out more that `@max_tokens_per_user` tokens, then add recepient to @cacheTokens[sender]'s list.
      # note that this allows someone to send multiple tokens to the same user
      if @tokens_given[sender].length < @max_tokens_per_user
        @tokens_given[sender].push recipient
        @robot.brain.data.tokens_given = @tokens_given

        # update @tokens_received
        @tokens_received[recipient] ?= []
        @tokens_received[sender].push sender
        @robot.brain.data.tokens_received = @tokens_received
        
        return "#{sender} gave one token to #{recipient}."
      else
        return "#{sender}: you do not have any more tokens available to give to others. If you want, revoke a token using the command `revoke @user_name`."

    else
      return "Sorry #{sender}, tokens can no longer be given nor revoked."
      # TODO: if @tokens_given[sender].length >= @max_tokens_per_user, we want to send a message to the user saying that they've already given out all their tokens
      # Send a message like the following:
      #     You do not have any more tokens to give out. Type "token status" to find out to whom you have given your tokens, and type "token revoke @username" to revoke a token from @username.

      # TODO: send a message that announces that a token was given using a command like
      #       msg.send "#{subject} #{karma.receive_token_response()} (Karma: #{karma.get(subject)})"
      # in the robot.hear /(\S+[^+:\s])[: ]*\+\+(\s|$)/, (msg) function (or the equivalent that we write)

  revoke_token: (sender, recipient) ->
    # remove recipient from @tokens_given[sender] and remove sender from @tokens_received[recipient] 
    # note that if the sender has given >1 token to recipient, this will remove just one of those tokens from the recipient.
    if @tokens_can_be_revoked
      # remove recipient from @tokens_given[sender]
      index = @tokens_given[sender].indexOf recipient
      @tokens_given.splice index, 1 if index isnt -1

      # remove sender from @tokens_received[recipient]
      index = @tokens_received[recipient].indexOf sender
      @tokens_received.splice index, 1 if index isnt -1

      if index isnt -1
        return "#{sender} revoked one token from #{recipient}."
      else
        return "#{sender}: #{recipient} does not have any tokens from you, so you cannot revoke a token from #{recipient}."
    else
      return "Sorry #{sender}, tokens can no longer be given nor revoked."
    # TODO: send a message using 
    #       msg.send "#{subject} #{karma.revoke_token_response()} (Karma: #{karma.get(subject)})"
    # in the robot.hear /(\S+[^+:\s])[: ]*\+\+(\s|$)/, (msg) function
  # return a uniformly random response for giving a token to someone someone's karma

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
    # return the number of tokens given and to whom

    # list of the people to whom `name` has given tokens
    tokens_given_by_this_person = if @tokens_given[name]? then @tokens_given[name] else []
    num_tokens_given = tokens_given_by_this_person.length


    # build up a string of results
    result = ""

    # number of tokens this person has left to give others
    tokens_remaining = @max_tokens_per_user - num_tokens_given
    result += "#{name} has " + tokens_remaining + (if tokens_remaining != 1 then "s" else "") + " remaining to give to others."

    if num_tokens_given > 0
      result += "#{name} has given " + num_tokens_given + "token" + (if num_tokens_given != 1 then "s" else "") + "s to the following people:"
      for own name, number of tally(tokens_given_by_this_person)
        result += "\t#{name}: #{number} tokens\n"
    else
      result += "#{name} has not given any tokens to others yet."


    # tokens received from others
    tokens_received_by_this_person = if @tokens_received[name]? then @tokens_received[name] else []
    num_tokens_received = tokens_received_by_this_person.length
    if num_tokens_received > 0
      result += "#{name} has received " + num_tokens_received + "token" + (if num_tokens_received != 1 then "s" else "") + "s from the following people:"
      for own name, number of tally(@tokens_given[name])
        result += "\t#{name}: #{number} tokens\n"
    else
      result += "#{name} has not received any tokens from other people yet."

    return result
    # displays how many of your tokens you still have, and how many you have given to other people, 
    # and how many tokens you have received from other users

    # Example:
    # You have 2 of your own tokens in your pocket. 
    # You have given tokens to the following people: 
    # @user_4 (1 token)
    # @user_8 (2 tokens) 
    # You have received 2 tokens from others: 
    # @user_4 (1 token)
    # @user_5 (1 token)
    

    # in the code that listens for this command, we could display this if 
    #       msg.message.user.name.toLowerCase() == subject 
    # where subject = subject = msg.match[1].toLowerCase()
    # Way to go! Get more tokens by contributing to others' ideas. Each token from a winning business proposal earns prize money.


module.exports = (robot) ->
  tokenBot = new TokenNetwork robot

  # we export a function of one variable, the `robot`, which `.hear`s messages and then does stuff

  # name of the bot 
  bot_name = process.env.HUBOT_ROCKETCHAT_BOTNAME


  # environment variables
  allow_self = process.env.TOKEN_ALLOW_SELF # whether someone can give a token to himself

  robot.hear /badger/i, (res) ->
    res.send "Badgers? BADGERS? WE DON'T NEED NO STINKIN BADGERS!!!"

  robot.hear /(\S+[^+:\s])[: ]*\+\+(\s|$)/, (msg) ->
  # `msg.match(regex)` checks whether msg matches the regular expression regex. I'm not sure what `msg.match[1]` does. 
  # Does the [1] refer to the first capturing group in the regular expression /(\S+[^+:\s])[: ]*\+\+(\s|$)/? 
  # Or does [1] refer to the first argument of this function?
    sender = msg.message.user.name
    recipient = msg.match[1].toLowerCase()
    if allow_self is true or msg.message.user.name.toLowerCase() != subject
      message = tokenBot.give_token msg.message.user.name, recipient
      msg.send message
      #karma.increment subject
      #msg.send "#{subject} #{karma.incrementResponse()} (Karma: #{karma.get(subject)})"
    else
      msg.send msg.random karma.selfDeniedResponses(msg.message.user.name)

###### end Charlie's code #######



