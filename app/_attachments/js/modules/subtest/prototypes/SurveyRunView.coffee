# these could easily be refactored into one.

ResultOfQuestion = (name) ->
  returnView = null
  for candidateView in vm.currentView.subtestViews[vm.currentView.index].prototypeView.questionViews
    if candidateView.model.get("name") == name
      returnView = candidateView
  throw new ReferenceError("ResultOfQuestion could not find variable #{name}") if returnView == null
  return returnView.answer if returnView.answer
  return null

ResultOfMultiple = (name) ->
  result = []
  for input in $("#question-#{name} input:checked")
    result.push $(input).val()
  return result

ResultOfPrevious = (name) ->
  return vm.currentView.result.getVariable(name)

ResultCSV =  (name) ->
  return "hey"

class SurveyRunView extends Backbone.View

  className: "SurveyRunView"

  events:
    'change input'        : 'updateSkipLogic'
    'change textarea'     : 'updateSkipLogic'
    'click .next_question' : 'nextQuestion'
    'click .prev_question' : 'prevQuestion'

  nextQuestion: ->

    currentQuestionView = @questionViews[@questionIndex]

    # show errors before doing anything if there are any
    return @showErrors(currentQuestionView) unless @isValid(currentQuestionView)

    # find the non-skipped questions
    isAvailable = []
    for question, i in @questionViews
      q$el = $(@questionViews[i].el)
      isAutostopped  = q$el.hasClass("disabled_autostop")
      isLogicSkipped = q$el.hasClass("disabled_skipped")
      isAvailable.push i if not (isAutostopped or isLogicSkipped)
    isAvailable  = _.filter isAvailable, (e) => e > @questionIndex



    # don't go anywhere unless we have somewhere to go
    if isAvailable.length == 0
      plannedIndex = @questionIndex
    else
      plannedIndex = Math.min.apply(plannedIndex, isAvailable)

    if @questionIndex != plannedIndex
      @questionIndex = plannedIndex
      @updateQuestionVisibility()
      @updateProgressButtons()

  prevQuestion: ->

    currentQuestionView = @questionViews[@questionIndex]

    # show errors before doing anything if there are any
    return @showErrors(currentQuestionView) unless @isValid(currentQuestionView)

    # find the non-skipped questions
    isAvailable = []
    for question, i in @questionViews
      q$el = $(@questionViews[i].el)
      isAutostopped  = q$el.hasClass("disabled_autostop")
      isLogicSkipped = q$el.hasClass("disabled_skipped")
      isAvailable.push i if not (isAutostopped or isLogicSkipped)
    isAvailable  = _.filter isAvailable, (e) => e < @questionIndex

    # don't go anywhere unless we have somewhere to go
    if isAvailable.length == 0
      plannedIndex = @questionIndex
    else
      plannedIndex = Math.max.apply(plannedIndex, isAvailable)

    if @questionIndex != plannedIndex
      @questionIndex = plannedIndex
      @updateQuestionVisibility()
      @updateProgressButtons()

  updateProgressButtons: ->

    isAvailable = []
    for question, i in @questionViews
      q$el = $(@questionViews[i].el)
      isAutostopped  = q$el.hasClass("disabled_autostop")
      isLogicSkipped = q$el.hasClass("disabled_skipped")
      isAvailable.push i if not (isAutostopped or isLogicSkipped)
    isAvailable.push @questionIndex

    $prev = @$el.find(".prev_question")
    $next = @$el.find(".next_question")

    minimum = Math.min.apply( minimum, isAvailable )
    maximum = Math.max.apply( maximum, isAvailable )

    if @questionIndex == minimum
      $prev.hide()
    else
      $prev.show()

    if @questionIndex == maximum
      $next.hide()
    else
      $next.show()

  updateExecuteReady: (ready) =>
    @executeReady = ready
    return if not @triggerShowList?
    if @triggerShowList.length > 0
      for index in @triggerShowList
        @questionViews[index]?.trigger "show"
      @triggerShowList = []


  updateQuestionVisibility: ->

    return unless @model.get("focusMode")

    if @questionIndex == @questionViews.length
      @$el.find("#summary_container").html "
        last page here
      "
      @$el.find("#next_question").hide()
    else
      @$el.find("#summary_container").empty()
      @$el.find("#next_question").show()

    $questions = @$el.find(".question")
    $questions.hide()
    $questions.eq(@questionIndex).show()

    # trigger the question to run it's display code if the subtest's displaycode has already ran
    # if not, add it to a list to run later.
    if @executeReady 
      @questionViews[@questionIndex].trigger "show"
    else
      @triggerShowList = [] if not @triggerShowList
      @triggerShowList.push @questionIndex

  showQuestion: (index) ->
    @questionIndex = index if _.isNumber(index) && index < @questionViews.length && index > 0
    @updateQuestionVisibility()
    @updateProgressButtons()

  initialize: (options) ->
    @model         = @options.model
    @parent        = @options.parent
    @isObservation = @options.isObservation
    @focusMode     = @model.getBoolean("focusMode")
    @questionIndex = 0 if @focusMode
    @questionViews = []
    @answered      = []
    @renderCount   = 0
    @questions     = new Questions
    @questions.db.view = "questionsBySubtestId"
    @questions.fetch
      key: @model.id
      success: (collection) =>
        @questions = collection
        @questions.sort()
        @ready = true
        @render()

  # when a question is answered
  onQuestionAnswer: (event) =>
    if @isObservation

      # find the view of the question
      cid = $(event.target).attr("data-cid")
      for view in @questionViews
        if view.cid == cid && view.type != "multiple" # if it's multiple don't go scrollin

          # find last or next not skipped
          next = $(view.el).next()
          while next.length != 0 && next.hasClass("disabled_skipped")
            next = $(next).next()
          
          # if it's not the last, scroll to it
          if next.length != 0
            next.scrollTo()

    # auto stop after limit
    @autostopped    = false
    autostopLimit   = parseInt(@model.get("autostopLimit")) || 0
    longestSequence = 0
    autostopCount   = 0

    if autostopLimit > 0
      for i in [1..@questionViews.length] # just in case they can't count
        currentAnswer = @questionViews[i-1].answer
        if currentAnswer == "0" or currentAnswer == "9"
          autostopCount++
        else
          autostopCount = 0
        longestSequence = Math.max(longestSequence, autostopCount)
        # if the value is set, we've got a threshold exceeding run, and it's not already autostopped
        if autostopLimit != 0 && longestSequence >= autostopLimit && not @autostopped
          @autostopped = true
          @autostopIndex = i
    @updateAutostop()
  
  updateAutostop: ->
    autostopLimit = parseInt(@model.get("autostopLimit")) || 0
    for view, i in @questionViews
      if i > (@autostopIndex - 1)
        view.$el.addClass    "disabled_autostop" if     @autostopped
        view.$el.removeClass "disabled_autostop" if not @autostopped

  updateSkipLogic: =>
    @questions.each (question) ->
      skipLogicCode = question.get "skipLogic"
      if not _.isEmptyString(skipLogicCode)
        try
          result = CoffeeScript.eval.apply(@, [skipLogicCode])
        catch error
          name = ((/function (.{1,})\(/).exec(error.constructor.toString())[1])
          message = error.message
          alert "Skip logic error in question #{question.get('name')}\n\n#{name}\n\n#{message}"

        if result
          @$el.find("#question-#{question.get('name')}").addClass "disabled_skipped"
        else
          @$el.find("#question-#{question.get('name')}").removeClass "disabled_skipped"
    _.each @questionViews, (questionView) ->
      questionView.updateValidity()

  isValid: (views = @questionViews) ->
    return true if not views? # if there's nothing to check, it must be good
    views = [views] if not _.isArray(views)
    for qv, i in views
      qv.updateValidity()
      # can we skip it?
      if not qv.model.getBoolean("skippable")
        # is it valid
        if not qv.isValid
          # red alert!!
          return false
    return true

  getSkipped: ->
    result = {}
    result[@questions.models[i].get("name")] = "skipped" for qv, i in @questionViews
    return result

  getResult: =>
    result = {}
    for qv, i in @questionViews
      result[@questions.models[i].get("name")] =
        if qv.notAsked # because of grid score
          qv.notAskedResult
        else if not _.isEmpty(qv.answer) # use answer
          qv.answer
        else if qv.skipped 
          qv.skippedResult
        else if qv.$el.hasClass("disabled_skipped")
          qv.logicSkippedResult
        else if qv.$el.hasClass("disabled_autostop")
          qv.notAskedAutostopResult
        else
          qv.answer
    return result

  getSum: ->
    counts =
      correct   : 0
      incorrect : 0
      missing   : 0
      total     : 0

    for qv, i in @questionViews
      if _.isString(qv)
        counts.missing++
      else
        counts['correct']   += 1 if qv.isValid
        counts['incorrect'] += 1 if not qv.isValid
        counts['missing']   += 1 if not qv.isValid && ( qv.model.get "skippable" == 'true' || qv.model.get "skippable" == true )
        counts['total']     += 1 if true

    return {
      correct   : counts['correct']
      incorrect : counts['incorrect']
      missing   : counts['missing']
      total     : counts['total']
    }

  showErrors: (views = @questionViews) ->
    @$el.find('.message').remove()
    first = true
    views = [views] if not _.isArray(views)
    for qv, i in views
      if not _.isString(qv)
        message = ""
        if not qv.isValid

          # handle custom validation error messages
          customMessage = qv.model.get("customValidationMessage")
          if not _.isEmpty(customMessage)
            message = customMessage
          else
            message = t("please answer this question")

          if first == true
            @showQuestion(i) if views == @questionViews
            qv.$el.scrollTo()
            Utils.midAlert t("please correct the errors on this page")
            first = false
        qv.setMessage message

  render: ->
    return unless @ready
    @$el.empty()

    notAskedCount = 0
    @questions.sort()
    if @questions.models?
      for question, i in @questions.models
        # skip the rest if score not high enough

        required = parseInt(question.get("linkedGridScore")) || 0

        isNotAsked = ( ( required != 0 && @parent.getGridScore() < required ) || @parent.gridWasAutostopped() ) && @parent.getGridScore() != false

        if isNotAsked then notAskedCount++

        oneView = new QuestionRunView 
          model         : question
          parent        : @
          notAsked      : isNotAsked
          isObservation : @isObservation
        oneView.on "rendered", @onQuestionRendered
        oneView.on "answer scroll",   @onQuestionAnswer

        oneView.render()
        @questionViews[i] = oneView
        @$el.append oneView.el

      if @focusMode
        @updateQuestionVisibility()
        @$el.append "
          <div id='summary_container'></div>
          <button class='navigation prev_question'>Previous Question</button>
          <button class='navigation next_question'>Next Question</button>
        "
        @updateProgressButtons()


    if @questions.length == notAskedCount then @parent.next?()
    @trigger "rendered"

  onQuestionRendered: =>
    @renderCount++
    if @renderCount == @questions.length
      @trigger "ready"
      @updateSkipLogic()
    @trigger "subRendered"

  onClose:->
    for qv in @questionViews
      qv.close?()
    @questionViews = []
