var RegisterTeacherView,
  __hasProp = Object.prototype.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

RegisterTeacherView = (function(_super) {

  __extends(RegisterTeacherView, _super);

  function RegisterTeacherView() {
    RegisterTeacherView.__super__.constructor.apply(this, arguments);
  }

  RegisterTeacherView.prototype.events = {
    'click .register': 'register'
  };

  RegisterTeacherView.prototype.initialize = function(options) {
    this.name = options.name;
    this.pass = options.pass;
    return this.fields = ["first", "last", "gender", "school", "contact"];
  };

  RegisterTeacherView.prototype.register = function() {
    var _this = this;
    return this.validate(function() {
      return _this.saveUser();
    });
  };

  RegisterTeacherView.prototype.validate = function(callback) {
    var element, errors, _i, _len, _ref;
    errors = false;
    _ref = this.fields;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      element = _ref[_i];
      if (_.isEmpty(this[element].val())) {
        this.$el.find("#" + element + "_message").html("Please fill out this field.");
        errors = true;
      } else {
        this.$el.find("#" + element + "_message").html("");
      }
    }
    if (errors) {
      return Utils.midAlert("Please correct the errors on this page.");
    } else {
      return callback();
    }
  };

  RegisterTeacherView.prototype.saveUser = function() {
    var element, userDoc, _i, _len, _ref,
      _this = this;
    userDoc = {
      "name": this.name
    };
    _ref = this.fields;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      element = _ref[_i];
      userDoc[element] = this[element].val();
    }
    Tangerine.$db.saveDoc($.extend(userDoc, {
      "collection": "teacher"
    }));
    return $.couch.signup(userDoc, this.pass, {
      success: function() {
        Utils.midAlert("New teacher registered");
        return Tangerine.user.login(_this.name, _this.pass);
      },
      error: function(error) {
        return Utils.midAlert("Registration error<br>" + error, 5000);
      }
    });
  };

  RegisterTeacherView.prototype.render = function() {
    var element, x, _i, _len, _ref;
    this.$el.html("      <h1>Register new teacher</h1>      <table>        <tr>          <td class='small_grey'><b>Username</b></td>          <td class='small_grey'>" + this.name + "</td>          <td class='small_grey'><b>Password</b></td>          <td class='small_grey'>" + (((function() {
      var _i, _len, _ref, _results;
      _ref = this.pass;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        x = _ref[_i];
        _results.push("*");
      }
      return _results;
    }).call(this)).join('')) + "</td>        </tr>      </table>      <div class='label_value'>        <label for='first'>First name</label>        <div id='first_message' class='messages'></div>        <input id='first'>      </div>      <div class='label_value'>        <label for='last'>Last Name</label>        <div id='last_message' class='messages'></div>        <input id='last'>      </div>      <div class='label_value'>        <label for='gender'>Gender</label>        <div id='gender_message' class='messages'></div>        <input id='gender'>      </div>      <div class='label_value'>        <label for='school'>School name</label>        <div id='school_message' class='messages'></div>        <input id='school'>      </div>      <div class='label_value'>        <label for='contact'>Email address or mobile phone number</label>        <div id='contact_message' class='messages'></div>        <input id='contact'>      </div>      <button class='register command'>Register</button>    ");
    _ref = this.fields;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      element = _ref[_i];
      this[element] = this.$el.find("#" + element);
    }
    return this.trigger("rendered");
  };

  return RegisterTeacherView;

})(Backbone.View);
