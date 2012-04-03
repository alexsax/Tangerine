class Router extends Backbone.Router
  routes:
    "assessment/:id": "assessment"
#    "result/:id": "result"
    "results/tabular/:assessment_id": "tabular_results"
    "results/tabular/:assessment_id/*options": "tabular_results"
    "results/:assessmentId/:enumerator": "results"
    "print/:id": "print"
    "student_printout/:id": "student_printout"
    "login": "login"
    "logout": "logout"
    "manage": "manage"
    "edit/assessment/:assessment_id/subtest/:subtest_id": "editSubtest"
    "edit/assessment/:assessment_id": "editAssessment"
    "assessments": "assessments"
    "": "assessments"

  editSubtest: ( assessment_id, subtest_id ) ->
    @verify_logged_in
      success: ->
        assessment = new Assessment
          _id: assessment_id
        assessment.fetch
          success: ->
            Tangerine.subtestEdit ?= new SubtestEdit()
            Tangerine.subtestEdit.assessment = assessment
            Tangerine.subtestEdit.model = new Subtest
              _id: subtest_id
            Tangerine.subtestEdit.model.fetch
              success: ->
                Tangerine.subtestEdit.render()

  editAssessment: (assessment_id) ->
    @verify_logged_in
      success: ->
        assessment = new Assessment
          _id: assessment_id
        assessment.fetch
          success: ->
            Tangerine.assessmentEdit ?= new AssessmentEdit()
            Tangerine.assessmentEdit.model = new Assessment(assessment.attributes)
            Tangerine.assessmentEdit.render()
                

  results: (assessmentId,enumerator) ->
    @verify_logged_in
      success: ->
        resultCollection = new ResultCollection()
        resultCollection.fetch
          success: ->
            Tangerine.resultsView ?= new ResultsView()
            Tangerine.resultsView.assessment = new Assessment
              _id: assessmentId
            Tangerine.resultsView.assessment.fetch
              success: ->
                Tangerine.resultsView.results = resultCollection.filter (result) ->
                  result.get("assessmentId") is assessmentId and result.get("enumerator") is enumerator
                Tangerine.resultsView.render()

  
  # Have rewritten map/reduce views for this, need to refactor to use
  # Note that views are currently not created for any current system
  # Need to enable for cloud/laptop only situations
  tabular_results: (assessment_id) ->
    @verify_logged_in
      success: ->
        view = "reports/fields"
        # TODO - figure out what to do about this limit
        limit = 10000000
        $("#content").html("Loading maximum of #{limit} items from view: #{view} from #{assessment_id}")

        $.couch.db(Tangerine.database_name).view view,
          reduce: true
          group: true
          success: (result) ->
            uniqueFields = _.pluck result.rows, "key"

            $.couch.db(Tangerine.database_name).view view,
              reduce: false
              limit: limit
              success: (tableResults) ->
                Tangerine.resultsView ?= new ResultsView()
                options = jQuery.deparam.querystring(jQuery.param.fragment())
                Tangerine.resultsView.uniqueFields = uniqueFields
                Tangerine.resultsView.tableResults = tableResults
                Tangerine.resultsView.renderTable(options)
              

  result: (id) ->
    @verify_logged_in
      success: ->
        Tangerine.resultView ?= new ResultView()
        Tangerine.resultView.model = new Result(id)
        Tangerine.resultView.model.fetch
          success:->
            $("#content").html Tangerine.resultView.render()

  manage: ->
    if Tangerine.user.isAdmin()
      assessmentCollection = new AssessmentCollection()
      assessmentCollection.fetch
        success: ->
          Tangerine.manageView ?= new ManageView()
          Tangerine.manageView.render(assessmentCollection)

  assessments: ->
    if Tangerine.user.isVerified()
      Tangerine.assessmentListView ?= new AssessmentListView()
      Tangerine.assessmentListView.render()
    else
      Tangerine.router.navigate "login", true

  login: ->
    Tangerine.loginView.render()

  logout: ->
    Tangerine.user.logout()

  assessment: (id) ->
    if Tangerine.user.isVerified()
      # This is terrible but it fixes my problem
      # Currently live click handlers get duplicated over and over again
      # Need to convert everything to backbone style views
      # Not only backbone style views, but reuse views or destroy them
      if Tangerine.assessment?
        location.reload()
      
      Tangerine.assessment = new Assessment { _id : id }
      Tangerine.assessment.fetch
        success: ->
          Tangerine.assessment.render()

  verify_logged_in: (options) ->
    $.couch.session
      success: (session) =>
        
        Tangerine.enumerator = session.userCtx.name
        Tangerine.userRoles = _.values session.userCtx.roles 
        
        Tangerine.router.targetroute = document.location.hash
        
        unless session.userCtx.name
          Tangerine.router.navigate("login", true)
          return
        #@handle_menu session
        options.success session

  print: (id) ->
    Assessment.load id, (assessment) ->
      assessment.toPaper (result) ->
        style = "
          body{
            font-family: Arial;
          }
          .page-break{
            display: block;
            page-break-before: always;
          }
          input{
            height: 50px;  
            border: 1px
          }
        "
        $("body").html(result)
        # Remove the jquery mobile stylesheet
        $("link").remove()

  student_printout: (id) ->
    Assessment.load id, (assessment) ->
      assessment.toPaper (result) ->
        style = "
          <style>
            body{
              font-family: Arial;
              font-size: 200%;
            }
            .page-break{
              display: none;
            }
            input{
              height: 50px;  
              border: 1px;
            }
            .subtest.ToggleGridWithTimer{
              page-break-after: always;
              display:block;
              padding: 15px;
            }
            .subtest, button, h1{
              display:none;
            }
            .grid{
              display: inline;
              margin: 5px;
            }
          </style>
        "
        $("style").remove()
        $("body").html(result + style)
        $("span:contains(*)").parent().remove()
        # Remove the jquery mobile stylesheet
        $("link").remove()

        $('.grid').each (index) ->
          $(this).nextAll().andSelf().slice(0,10).wrapAll('<div class="grid-row"></div>') if( index % 10 == 0 )


# Initialization/Detection
$ -> # run after DOM loads

  #    Detect admin party mode
  #    $.couch.config(
  #      {
  #        success: (result) ->
  #          if _.keys(result).length == 0 # admin party mode
  #            $.couch.config({},"admins",Tangerine.config.user_with_database_create_permission, Tangerine.config.password_with_database_create_permission)
  #        error: ->
  #          # Do nothing - we can't access this because we are not admins
  #      }
  #      "admins"
  #    )

  # Should remove later - always make sure the timeout is 28800 (8 hrs)
  #    $.ajax "/_config/couch_httpd_auth/timeout",
  #    username: Tangerine.config.user_with_database_create_permission
  #    password: Tangerine.config.password_with_database_create_permission
  #    type: "put"
  #    data: '"28800"'

  #
  # Start the application
  #
  
  # load config
  config = new Backbone.Model
    _id: "Config"
  config.fetch
    success: =>
      Tangerine.config = config.toJSON()

  # Reuse the view objects to stop events from being duplicated (and to save memory)
  

  # Durables
  # Things here should be reused
  Tangerine.user   = new User()
  Tangerine.loginView = new LoginView( Tangerine.user )
  Tangerine.router = new Router()
  #Tangerine.dispatch = _.clone Backbone.Events
  
  Tangerine.navi = new Navigation
    user   : Tangerine.user
    router : Tangerine.router

  Backbone.history.start()

  #
  # Set up some interface stuff
  #
  $(".ajax_loading").ajaxStart ->
    $("#corner_logo").attr "src", "images/spin_orange.gif"

  $(".ajax_loading").ajaxStop ->
    $("#corner_logo").attr "src", "images/corner_logo.png"
    
  $("#version").load 'version'

  $( '#main_nav button' ).click (event) ->
    Tangerine.router.navigate( $( event.target ).attr( "href" ), true );
