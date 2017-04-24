

GuestRideReserverCtrl = ($scope, Guests, GuestRoomRezOnDate, AvailableSeatsForLeg, OtherRidesWithAvailableSeats, CreateGuest) ->
  ctrl = this
  ctrl.transitions = []
  ctrl.INIT = 'init'
  ctrl.START = 'start'
  ctrl.CHECK_SEATS = 'check-seats'
  ctrl.FIND_OTHER_RIDES = 'find-other-rides'
  ctrl.START_CREATE = 'start-create'
  ctrl.SHOW_OTHER_RIDES = 'show-other-rides'
  ctrl.SHOW_NO_RIDES = 'show-no-rides'
  ctrl.FIND_GUEST = 'find-guest'
  ctrl.FIND_RELATED_GUEST = 'find-related-guest'
  ctrl.CREATE_GUEST = 'create-guest'
  ctrl.RESERVE_ROOM = 'reserve-room'
  ctrl.ASSIGN_ROOM = 'assign-room'
  ctrl.DISAMBIGUATE_GUEST = 'disambiguate-guest'
  ctrl.SUCCESS = 'success'
  ctrl.CANCEL = 'cancel'
  ctrl.RESERVE_RIDE = 'reserve-ride'
  ctrl.CREATE_GUEST_WITH_RELS = 'create-guest-with-relationships'

  ctrl.view = {
    canCheckSeats: false
    canMakeRideReservation: false
  }

  ctrl.seats = {
    numRequested: null
    numAvailable: null
    haveEnough: false
  }

  ctrl.addTransition = (newTransition) ->
    return transition for transition in ctrl.transitions when transition.fromState == newTransition.fromState
    if transition?
      transition.watches.push(newTransition.watch)
    else
      ctrl.transitions.push ( { fromState: newTransition.fromState, watches: newTransition.watch } )


  # VIEW STATE
  ctrl.viewState = {
    start: {
      goodReservation: false
      checkSeatsBtn: false
      reserveRideBtn: false
      otherRidesBtn: false
      otherRidesGT1: false
      notificationDlg: false
      noRidesAlert: false
      notifyBtn: false
    }
    checkSeats: {
      goodReservation: false
      checkSeatsBtn: true
      reserveRideBtn: false
      otherRidesBtn: false
      otherRidesGT1: false
      notificationDlg: false
      noRidesAlert: false
      notifyBtn: false
    }
    findGuest: {
      goodReservation: false
      checkSeatsBtn: false
      reserveRideBtn: false
      otherRidesBtn: false
      otherRidesGT1: false
      notificationDlg: false
      noRidesAlert: false
      notifyBtn: false
    }
    otherRides: {
      goodReservation: false
      checkSeatsBtn: false
      reserveRideBtn: false
      otherRidesBtn: true
      otherRidesGT1: false
      notificationDlg: false
      noRidesAlert: false
      notifyBtn: false
    }
    noRides: {
      goodReservation: false
      checkSeatsBtn: false
      reserveRideBtn: false
      otherRidesBtn: false
      otherRidesGT1: false
      notificationDlg: false
      noRidesAlert: true
      notifyBtn: false
    }
  }

  # FORM STATE

  ctrl.defaultFormState = {
    guest: {
      name: {
        last: undefined
        first: undefined
        full: undefined
        long: undefined
      }
      contact: {
        landLine: undefined
        twitter: undefined
        skype: undefined
        mobile: undefined
        email: undefined
      }
      reservation: {
        checkedIn: undefined
        dates: {
          checkIn: undefined
          checkOut: undefined
        }
      }
      room: {
        number: undefined
      }
      leg: {
        departure: {
          stop: {
            default: route.defaultLeg.fromStop # Stop
            selected: undefined # Stop
          }
        }
        arrival: {
          stop: {
            default: route.defaultLeg.toStop # Stop
            selected: undefined # Stop
          }
        }
      }
    }
  }

  ctrl.resetFormState = ->
    ctrl.formState = angular.copy(ctrl.defaultFormState)

  ctrl.reset = ->
    ctrl.transitions.reset()
    ctrl.resetFormState()

  ctrl.reset()

  ###
  start:      'viewStartState'
  checkSeats: 'viewCheckSeatsState'
  create:     'viewCreateState'
  cancel:     'viewCancelState'
  otherRides: 'viewOtherRidesState'
  noRides:    'viewNoRidesState'
  success:    'viewSuccessState'
  failed:     'viewFailedState'
  notify:     'viewNotifyState'
  ###


  ctrl.transitions.add(
    {
      fromState: ctrl.START
      watch: ->
        ctrl.$watchGroup(
          [ ctrl.lastName, ctrl.fromStop, ctrl.toStop ],
          (newVals, oldVals, scope) ->
            if ctrl.canEnableCheckSeats()
              ctrl.enableCheckSeatsView()
              ctrl.arm(ctrl.CAN_CHECK_SEATS)
        )
    }
  )

  ctrl.transitions.add(
    {
      fromState: ctrl.CAN_CHECK_SEATS
      watch: ->
        ctrl.$watchGroup(
          [ ctrl.lastName, ctrl.fromStop, ctrl.toStop ],
          (newVals, oldVals, scope) ->
            if !ctrl.canEnableCheckSeats()
              ctrl.disableCheckSeatsView()
              ctrl.arm(ctrl.START)
        )
    }
  )

  ctrl.transitions.add(
    {
      fromState: ctrl.CAN_CHECK_SEATS
      watch: ->
        ctrl.$watch(
          numSeatsAvailable,
          (newVal, oldVal, scope) ->
            if ctrl.haveEnoughSeats()
              ctrl.disableCheckSeatsView()
              ctrl.enableMakeRideReservationView()
            ctrl.arm(ctrl.GUEST_LOOKUP)
        )
    }
  )

  ctrl.transitions.add(
    {
      fromState: ctrl.CAN_CHECK_SEATS
      toState: ctrl.HAVE_RIDE_WITH_ENOUGH_SEATS_LATER_TODAY
    }
  )

  ctrl.transitions.add(
    {
      fromState: ctrl.CAN_CHECK_SEATS
      toState: ctrl.DONT_HAVE_RIDE_WITH_ENOUGH_SEATS_LATER_TODAY
    }
  )


  # called from view when check-seats btn clicked
  ctrl.checkSeats = ->
    _seats = AvailableSeatsForLeg.get(
      ride_id: ride?.id,
      from_stop_id: ctrl.fromStop()?.id,
      to_stop_id: ctrl.toStop()?.id
    )
    _seats.$promise.then(->
      ctrl.setNumSeatsAvailable(_seats.numAvailable)
      if !ctrl.haveEnoughSeats()
        ctrl.ridesWithEnoughSeatsLaterToday =
          OtherRidesWithAvailableSeats.query(
            {
              num_seats: ctrl.numSeatsRequested()
              from_stop_id: ctrl.fromStop()?.id
              to_stop_id: ctrl.toStop()?.id
              excluded_ride_id: ride?.id
            }
          )
        ctrl.ridesWithEnoughSeatsLaterToday.$promise.then(->
          _numRides = ctrl.ridesWithEnoughSeatsLaterToday.length
          ctrl.state = switch _numRides
            # TODO - THIS LOGIC BELONGS IN TRANSITION DEFS
            when 1
              ctrl.HAVE_RIDE_WITH_ENOUGH_SEATS_LATER_TODAY
            when _numRides > 1
              ctrl.HAVE_RIDES_WITH_ENOUGH_SEATS_LATER_TODAY
            else
              ctrl.DONT_HAVE_RIDE_WITH_ENOUGH_SEATS_LATER_TODAY
        )
    )


  ctrl.transitions.add(
    {
      fromState:  ctrl.CHECK_SEATS_ENABLED
      watchExprs: ['state']
      can:        -> ctrl.state == ctrl.REQUESTED_SEATS_ARE_AVAILABLE_FOR_RIDE_LEG
      action:     ctrl.enableMakeRideReservation
      toState:    ctrl.REQUESTED_SEATS_ARE_AVAILABLE_FOR_RIDE_LEG
    }
  )

  ctrl.transitions.add(
    {
      fromState:  ctrl.CHECK_SEATS_ENABLED
      watchExprs: ['state']   # todo - watcher array should be a Set to avoid duplicating watchers such as 'state'
      can:        -> ctrl.state == ctrl.REQUESTED_SEATS_ARE_NOT_AVAILABLE_FOR_RIDE_LEG
      action:     ctrl.findRidesForLaterTodayWithNumSeatsRequestedForRideLeg # makes REST call
      toState:    ctrl.REQUESTED_SEATS_ARE_NOT_AVAILABLE_FOR_RIDE_LEG
    }
  )

  ctrl.transitions.add(
    {
      fromState:  ctrl.REQUESTED_SEATS_ARE_NOT_AVAILABLE_FOR_RIDE_LEG
      watchExprs: [ ctrl.ridesForLaterTodayWithNumSeatsRequestedForRideLeg ] # value changed when REST promise fulfilled
      can:        ctrl.foundRidesForLaterTodayWithNumSeatsRequestedForRideLeg
      action:     ctrl.openSelectRideForLaterTodayModal
      toState:    ctrl.FOUND_RIDES_FOR_LATER_TODAY_WITH_NUM_SEATS_REQUESTED_FOR_RIDE_LEG
    }
  )

  ctrl.transitions.add(
    {
      fromState:  ctrl.REQUESTED_SEATS_ARE_NOT_AVAILABLE_FOR_RIDE_LEG
      watchExprs: [ ctrl.ridesForLaterTodayWithNumSeatsRequestedForRideLeg ]
      can:        ctrl.foundNoRidesForLaterTodayWithNumSeatsRequestedForRideLeg
      action:     ctrl.disableMakeRideReservation
      toState:    ctrl.FOUND_NO_RIDES_FOR_LATER_TODAY_WITH_NUM_SEATS_REQUESTED_FOR_RIDE_LEG
    }
  )


  ctrl.transitions.add(
    {
      fromState:  ctrl.CHECK_SEATS,
      enabled:    ctrl.always
      trigger:    ctrl.autoTrigger
      action:     ctrl.findGuest
      toState:    ctrl.LOOKING_FOR_GUEST
      viewState:  ctrl.viewState.findGuest
    }
  )

  ctrl.transitions.add(
    {
      fromState:  ctrl.FIND_OTHER_RIDES,
      enabled:    ctrl.always
      trigger:    ctrl.autoTrigger
      action:     null
      toState:    ctrl.REVEAL_OTHER_RIDES
      viewState:  ctrl.viewState.revealOtherRides
    }
  )

  ctrl.transitions.add(
    {
      fromState:  ctrl.FIND_OTHER_RIDES,
      enabled:    ctrl.always
      trigger:    ctrl.autoTrigger
      action:     null
      toState:    ctrl.INDICATE_NO_RIDES
      viewState:  ctrl.viewState.indicateNoRides
    }
  )

  ctrl.transitions.add(
    {
      fromState:  ctrl.LOOKING_FOR_GUEST,
      enabled:    ctrl.guestNotFound
      action:     ctrl.createGuest
      toState:    ctrl.GUEST_SELECTED
    }
  )

  ctrl.transitions.add(
    {
      fromState:  ctrl.LOOKING_FOR_GUEST,
      enabled:    ctrl.oneGuestFound
      action:     null
      toState:    ctrl.GUEST_SELECTED
    }
  )

  ctrl.transitions.add(
    {
      fromState:  ctrl.LOOKING_FOR_GUEST,
      enabled:    ctrl.multipleGuestsFound
      action:     ctrl.letUserSelectGuest
      toState:    ctrl.GUEST_SELECTED
    }
  )

  ctrl.transitions.add(
    {
      fromState:  ctrl.GUEST_SELECTED,
      enabled:    ctrl.guestSelected
      action:     ctrl.findGuestsRelatedToSelectedGuest
      toState:    ctrl.LOOKING_FOR_RELATED_GUEST
      viewState:  ctrl.viewState.letUserChooseGuest
    }
  )

  ctrl.transitions.add(
    {
      fromState:  ctrl.LOOKING_FOR_RELATED_GUEST,
      enabled:    ctrl.haveGuestAndOtherGuestsWithCommonContactInfo
      action:     ctrl.letUserSelectGuestRelationships
      toState:    ctrl.CHOOSE_RELATED_GUESTS
      viewState:  ctrl.viewState.chooseRelatedGuests
    }
  )

  ctrl.transitions.add(
    {
      fromState:  ctrl.CHOOSE_RELATED_GUESTS
      enabled:    ctrl.relatedGuestsChosen
      action:     ctrl.findRoomReservationsForGuestDuringRideTime
      toState:    ctrl.FIND_ROOM_RESERVATIONS_FOR_GUEST_DURING_RIDE_TIME
      viewState:  ctrl.viewState.findRoomReservationsForGuestDuringRideTime
    }
  )

  ctrl.transitions.add(
    {
      fromState:  ctrl.LOOKING_FOR_RELATED_GUEST
      enabled:    ctrl.haveGuestAndNoOtherGuestsWithCommonContactInfo
      action:     ctrl.findRoomReservationsForGuestDuringRideTime
      toState:    ctrl.FIND_ROOM_RESERVATIONS_FOR_GUEST_DURING_RIDE_TIME
      viewState:  ctrl.viewState.findRoomReservationsForGuestDuringRideTime
    }
  )

  ctrl.transitions.add(
    {
      fromState:  ctrl.FIND_ROOM_RESERVATIONS_FOR_GUEST_DURING_RIDE_TIME
      enabled:    ctrl.haveGuest
      action:     null
      toState:    ctrl.HAVE_NO_ROOM_RESERVATIONS_FOR_GUEST_DURING_RIDE_TIME
      viewState:  ctrl.viewState.haveNoRoomReservationsForGuestDuringRideTime
    }
  )

  ctrl.transitions.add(
    {
      fromState:  ctrl.FIND_ROOM_RESERVATIONS_FOR_GUEST_DURING_RIDE_TIME
      enabled:    ctrl.haveGuest
      action:     null
      toState:    ctrl.HAVE_ROOM_RESERVATIONS_FOR_GUEST_DURING_RIDE_TIME
      viewState:  ctrl.viewState.haveRoomReservationsForGuestDuringRideTime
    }
  )

  ctrl.transitions.add(Transition.FIND_ROOM_RESERVATIONS_FOR_GUEST,  Transition.FIND_ROOMS_ASSIGNED_TO_GUEST,                    ctrl.assignRoom,          ctrl.viewState.assignRoom)
  ctrl.transitions.add(Transition.FIND_ROOM_RESERVATIONS_FOR_GUEST,  Transition.ASSIGN_ROOM_TO_GUEST,                    ctrl.assignRoom,          ctrl.viewState.assignRoom)

  ctrl.transitions.add(Transition.FIND_ROOMS_ASSIGNED_TO_GUEST,  Transition.SELECT_ROOM_FROM_THOSE_ASSIGNED_TO_GUEST,                    ctrl.assignRoom,          ctrl.viewState.assignRoom)
  ctrl.transitions.add(Transition.FIND_ROOMS_ASSIGNED_TO_GUEST,  Transition.ASSIGN_ROOM_TO_ROOM_RESERVATION_FOR_GUEST,                    ctrl.assignRoom,          ctrl.viewState.assignRoom)


  ctrl.transitions.add(Transition.FIND_ROOM,                     Transition.ASSIGN_ROOM_TO_GUEST,                  ctrl.assignRoom,          ctrl.viewState.assignRoom)
  ctrl.transitions.add(Transition.FIND_ROOM,                     Transition.FIND_ROOM_RESERVATION,        ctrl.assignRoom,          ctrl.viewState.assignRoom)

  ctrl.transitions.add(Transition.FIND_ROOM_RESERVATION,         Transition.ASSIGN_ROOM_TO_ROOM_RESERVATION,                  ctrl.assignRoom,          ctrl.viewState.assignRoom)

  ctrl.transitions.add(Transition.CREATE_GUEST,                  Transition.RESERVE_ROOM,                 ctrl.reserveRoom)

  ctrl.transitions.add(Transition.RESERVE_ROOM,                  Transition.ASSIGN_ROOM,                  ctrl.assignRoom)

  ctrl.transitions.add(Transition.ASSIGN_ROOM,                   Transition.RESERVE_RIDE,                 ctrl.reserveRide)
  ctrl.transitions.add(Transition.ASSIGN_ROOM,                   Transition.CANCEL,                       ctrl.cancel)

  ctrl.transitions.add(Transition.DISAMBIGUATE_GUEST,            Transition.FIND_RELATED_GUEST,           ctrl.findRelatedGuest)
  ctrl.transitions.add(Transition.DISAMBIGUATE_GUEST,            Transition.ASSIGN_GUEST_TO_ROOM,         ctrl.assignGuestToRoom)
  ctrl.transitions.add(Transition.DISAMBIGUATE_GUEST,            Transition.CANCEL,                       ctrl.cancel)
  ctrl.transitions.add(Transition.DISAMBIGUATE_GUEST,            Transition.CREATE_GUEST,                 ctrl.createGuest)
  ctrl.transitions.add(Transition.FIND_RELATED_GUEST,            Transition.CREATE_GUEST_WITH_RELS,       ctrl.createGuestWithRels)
  ctrl.transitions.add(Transition.FIND_RELATED_GUEST,            Transition.CREATE_GUEST,                 ctrl.createGuest)
  ctrl.transitions.add(Transition.CREATE_GUEST_RIDE_REZ,         Transition.SUCCESS,                      ctrl.createdGuestRideRez)
  ctrl.transitions.add(Transition.CREATE_GUEST_RIDE_REZ,         Transition.CANCEL,                       ctrl.cancel)
  ctrl.transitions.add(Transition.CREATE_GUEST_WITH_RELS,        Transition.ASSIGN_GUEST_TO_ROOM,         ctrl.assignGuestToRoom)
  ctrl.transitions.add(Transition.CREATE_GUEST_WITH_RELS,        Transition.CANCEL,                       ctrl.cancel)

  # UTILITIES

  ctrl.haveLastName = ->
    ctrl.formState.guest.name.last? && ctrl.formState.guest.name.last != ''

  ctrl.haveNumSeatsRequest = ->
    ctrl.formState.numSeats.requested > 0

  ctrl.numSeatsRequested = ->
    ctrl.seats.numRequested

  ctrl.numSeatsAvailable = ->
    ctrl.seats.numAvailable

  ctrl.setNumSeatsAvailable = (n) ->
    if n > 0
      ctrl.seats.numAvailable = n
    else
      ctrl.seats.numAvailable = 0

  ctrl.haveLegRequest = ->
    ctrl.formState.leg.departureStop.requested? and ctrl.formState.leg.arrivalStop.requested?

  ctrl.fromStop = ->
    ctrl.formState.leg.departure.stop.requested

  ctrl.toStop = ->
    ctrl.formState.leg.arrival.stop.requested

  ctrl.firstName = ->
    ctrl.formState.guest.name.first

  ctrl.lastName = ->
    ctrl.formState.guest.name.last

  ctrl.mobile = ->
    ctrl.formState.guest.contact.mobile

  ctrl.landLine = ->
    ctrl.formState.guest.contact.landLine

  ctrl.email = ->
    ctrl.formState.guest.contact.email

  ctrl.skype = ->
    ctrl.formState.guest.contact.skype

  ctrl.twitter = ->
    ctrl.formState.guest.contact.twitter

  # ENABLEMENTS

  ctrl.canEnableCheckSeats = ->
    ctrl.haveLastName() and ctrl.haveNumSeatsRequest() and ctrl.haveLegRequest()

  ctrl.cantEnableCheckSeats = ->
    !ctrl.canEnableCheckSeats()

  ctrl.haveEnoughSeats = ->
    ctrl.seats.numAvailable >= ctrl.seats.numRequested

  # VIEW SUPPORT

  ctrl.enableCheckSeatsView = ->
    ctrl.view.canCheckSeats = true

  ctrl.disableCheckSeatsView = ->
    ctrl.view.canCheckSeats = false

  ctrl.enableMakeRideReservationView ->
    ctrl.view.canMakeRideReservation = true

  ctrl.disableMakeRideReservationView ->
    ctrl.view.canMakeRideReservation = false




  # WATCHES

  ctrl.disarmers = null

  ctrl.arm = (fromState) ->
    if ctrl.disarmers? then d() for d in ctrl.disarmers
    ctrl.disarmers = (to.watch() for to in transition.to for transition in ctrl.transitions when transition.fromState is fromState)

  ctrl.arm(ctrl.START)


  # ACTIONS

  ctrl.enableCheckSeats = (nextState) ->
    ctrl.view.checkSeatsBtnEnabled = true
    ctrl.armState(nextState)

  ctrl.disableCheckSeats = (nextState) ->
    ctrl.view.checkSeatsBtnEnabled = false
    ctrl.armState(nextState)

  ctrl.findGuest = ->
    ctrl.foundGuests = Guests.query(
      {
        facility_id: facility.id
        last_name:   ctrl.lastName()
        first_name:  ctrl.firstName()
        mobile:      ctrl.mobile()
        land_line:   ctrl.landLine()
        email:       ctrl.email()
        skype:       ctrl.skype()
        twitter:     ctrl.twitter()
      }
    )
    ctrl.foundGuests.$promise.then(->
      switch ctrl.foundGuests.length
        when 0
          if mobile()? or landLine()? or email()? or skype()? or twitter()?
            ctrl.state = Transition.FIND_RELATED_GUEST
          else
            ctrl.state = Transition.CREATE_GUEST
        when 1
          ctrl.guest = ctrl.foundGuests[0]
          ctrl.state = Transition.ASSIGN_GUEST_TO_ROOM
        else
          ctrl.state = Transition.DISAMBIGUATE_GUEST
    )

  ctrl.createGuest = ->
    ctrl.guest = CreateGuest.save(
      {
        facility_id:          facility.id
        last_name:            ctrl.lastName()
        first_name:           ctrl.firstName()
        email:                ctrl.email()
        mobile:               ctrl.mobile()
        land_line:            ctrl.landLine()
        twitter:              ctrl.twitter()
        skype:                ctrl.skype()
        prefer_informal_name: 'false'
        status:               'active'
      }
    )
    ctrl.guest.$promise.then(->
      ctrl.state = Transition.RESERVE_ROOM
    )

  ctrl.reserveRoom = ->

  ctrl.disambiguateGuest = ->

  ctrl.findRelatedGuest = ->

  ctrl.assignRoom = ->
    ctrl.roomReservations = GuestRoomRezOnDate.query(
      facility_id: facility.id
      room_id:     ctrl.room.id
      starts:      ride.date
      ends:        ride.date
      status:      'active'
    )
    ctrl.roomReservations.$promise.then(->
      switch ctrl.roomReservations.length
        when 0
          roomReservation = GuestRoomReservation.save(
            {
              facility_id:     facility.id
              provider_id:     facility.id
              creator_id:      creator.id
              guest_id:        foundGuest.id
              room_id:         room.id
              starts:          if ctrl.formState.guest.dates.checkIn? then ctrl.formState.guest.dates.checkIn else ride.date
              ends:            if ctrl.formState.guest.dates.checkOut? then ctrl.formState.guest.dates.checkOut else ride.date
              waitlisted:      if ctrl.formState.guest.waitListed then 'true' else 'false'
              waitlist_expiry: ctrl.formState.guest.waitListExpiry
              checked_in:      if ctrl.formState.guest.room.checkedIn then 'true' else 'false'
              status:         'active'
            }
          )
          roomReservation.$promise.then(
            ->
              $log.debug('created room reservation: ' + roomReservation.id)
              Transition.to(STATE_CREATE_GUEST_RIDE_REZ)
          ,
            (reason) ->
              #setTopError(reason.ctrl.formState)
              #alert($scope.topError.message)
              roomReservation = null
              Transition.to(STATE_CANCEL)
              $log.debug('error creating room reservation: ' + reason)
          )
        when 1
          roomReservation = roomReservations[0]
          if roomReservation.guestId == foundGuest.id
            Transition.to(STATE_CREATE_GUEST_RIDE_REZ)
          else
            this.roommateIds = ( roommate.id for roommate in roomReservation.roommates when roommate.id is foundGuest.id )
            if this.roommateIds.length > 0
              Transition.to(STATE_CREATE_GUEST_RIDE_REZ)
            else
              personWithRoomRez = GuestById.get(facility_id: facility.id, guest_id: roomReservation.guestId)
              personWithRoomRez.$promise.then(->
                roommates = GuestsByIds.query(facility_id: facility.id, guest_ids: roommate.id for roommate in roomReservation.roommates)
                roommates.$promise.then(->
                  grrRoomConflictModal(personWithRoomRez, roomReservation, roommates)
                )
              )
        else
          $log.error('grrAssignGuestToRoom: Multiple room reservations found for room# ' + ctrl.formState.guest.room.number.specified + ' at ' + ride.date)
          roomReservation = null
          Transition.to(STATE_CANCEL)
    )

  ctrl.showOtherRides = ->

  ctrl.showNoRides = ->

  ctrl.cancel = ->

  ctrl.createdGuestRideRez = ->

  ctrl.createGuestRideRez = ->

  ctrl.createGuestWithRels = ->

  ctrl.mayCheckSeatAvailability = ->
    (
      ctrl.formState.guest.name.last? && ctrl.formState.guest.name.last != ''
    ) &&
    (
      (
        ctrl.formState.guest.room.checkedIn &&
        ctrl.formState.guest.room.number? &&
        ctrl.formState.guest.room.number != ''
      ) ||
      !ctrl.formState.guest.reservation.checkedIn
    )

  ctrl.selectNumSeats = (n) ->
    ctrl.formState.guest.numSeats.requested = n
    suffix = if n > 1 then 's' else ''
    $scope.seatBtnLbl =  'Reserve ' + n.toString() + ' Seat' + suffix
    $scope.seatBtnClass = 'glyphicon glyphicon-tag' + suffix
    switch totalReservableSeats - n
      when 0
        $scope.availableSeatsMsg = 'No seats available'
      when 1
        $scope.availableSeatsMsg = 'Only 1 seat available'
      else
        $scope.availableSeatsMsg = 'Only ' + n.toString() + ' seats available'
    if this.mayCheckSeatAvailability()
      this.updateViewState(false,true,false,false,false,false,false,false)

  ctrl.reserveRide = ->
    alert('reserve ride')

angular.module('gr').component('GuestRideReserver', {
  templateUrl: 'guestRideReserver.html'
  controller: GuestRideReserverCtrl
  bindings: {
    facility: '<'
    route: '<'
    ride: '<'
    guests: '<'
    addReservation: '&'
  }
})