class PrototypeSurveyView extends Backbone.View

  initialize: (options) ->
    @model         = @options.model
    @parent        = @options.parent
    @questionViews = []
    @questions     = []
    questions      = new Questions
    questions.fetch
      success: (collection) =>
        filteredCollection = collection.where { subtestId : @model.id }
        @questions = new Questions filteredCollection
        @questions.sort()
        @render()

  isValid: ->
    for qv, i in @questionViews
      # does it have a method? otherwise it's a string
      if qv.isValid?
        # can we skip it?
        if not ( qv.model.get("skippable") == "true" || qv.model.get("skippable") == true )
          # is it valid
          if not qv.isValid
            # red alert!!
            return false
    return true
    

  getResult: ->
    result = {}
    for qv, i in @questionViews
      # questions not asked are strings "not_asked"
      if _.isString qv
        result[@questions.models[i].get("name")] == qv
      else
        result = $.extend result, qv.result
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
        counts['missing']   += 1 if not qv.isValid && (qv.model.get "skippable" == 'true' || qv.model.get "skippable" == true)
        counts['total']     += 1 if true

    return {
      correct   : counts['correct']
      incorrect : counts['incorrect']
      missing   : counts['missing']
      total     : counts['total']
    }

  showErrors: ->
    @$el.find('.message').remove()
    first = true
    for qv, i in @questionViews
      if not _.isString(qv)
        message = ""
        if not qv.isValid
          message = "Please answer this question"
          if first == true
            qv.$el.scrollTo()
            Utils.midAlert "Please correct the errors on this page"
            first = false
        qv.setMessage message


  render: ->
    @questions.sort()
    if @questions.models?
      for question, i in @questions.models
        # skip the rest if score not high enough
        required = parseInt(question.get("linkedGridScore")) || 0
        if (required != 0 && @parent.getGridScore() < required)
          # if no question was asked, push a string rahter than a dummy view
          @questionViews[i] = "not_asked"
        else
          oneView = new QuestionView 
            model : question
            parent : @
          oneView.render()
          @questionViews[i] = oneView
          @$el.append oneView.el


    @trigger "rendered"

  onClose:->
    # QuestionView doesn't have a close methods - MVM
    #for qv in @questionViews
    #  qv.close()
    @questionViews = []
