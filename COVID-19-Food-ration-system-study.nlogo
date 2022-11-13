breed [markets market]
breed [residents resident]
breed [households household]

globals [
  time
  day
  population

  sd-susceptibility
  ave-incubation-period

  brgy-A-mean-susceptibility
  brgy-B-mean-susceptibility

  brgy-lockdown?

  isolated-residents

  ;;REPORTERS
  ; cummulative / brgy
  deaths-A
  deaths-B

  recoveries-A
  recoveries-B

  isolated-A
  isolated-B

  infected-A
  infected-B

  infected-cases-A
  infected-cases-B
  infected-cases-all
]

markets-own [
  brgy-A?
  brgy-B?
]

households-own
[
  brgy-A?
  brgy-B?

  occupied?

  persons-in-household
]

residents-own [
  brgy-A?
  brgy-B?

  susceptible?
  exposed?
  infected?
  recovered?

  isolated?
  moved-today?

  entry-time
  market-duration

  susceptibility-rate
  exposure-duration
  incubation-duration
  severe-symptoms-start
  hazard-rate

  preferred-market
  house
]

to setup
  clear-all
  setup-globals
  setup-patches
  setup-markets
  setup-households
  setup-residents
  reset-ticks
end


to setup-globals

  set fm-pass true
  set brgy-lockdown false
  set ration-system-brgy-A "irregular rations"
  set ration-system-brgy-B "irregular rations"

  set day -1

  set ave-incubation-period 7 * 24
  set brgy-A-mean-susceptibility (.0070407 * average-r0-brgy-A * average-r0-brgy-A) + (.1147984 * average-r0-brgy-A) - .0263777
  set brgy-B-mean-susceptibility (.0070407 * average-r0-brgy-B * average-r0-brgy-B) + (.1147984 * average-r0-brgy-B) - .0263777

  set sd-susceptibility .05

  set isolated-residents (list)

end

to setup-patches
  if brgy-lockdown = true [ask patches with [pxcor = 0] [set pcolor red]]
end

to setup-markets

  create-markets market-count-brgy-A
  [
    let x (random -38) - 2
    let y (random 39) - 19
    while [not (all? [neighbors] of patch x y [pcolor = black])]
    [
      set x (random -38) - 2
      set y (random 39) - 19
    ]
    setxy x y
    set brgy-A? true
    set brgy-B? false
  ]


  create-markets market-count-brgy-B
  [
    let x (random 38) + 2
    let y (random 39) - 19
    while [not (all? [neighbors] of patch x y [pcolor = black])]
    [
      set x (random 38) + 2
      set y (random 39) - 19
    ]

    setxy x y

    set brgy-B? true
    set brgy-A? false
  ]

  ask markets
  [
    ask neighbors [ set pcolor white ]
    set pcolor white

    set color blue
    set shape "house"
    set size 3
  ]

end

to setup-households

  create-households brgy-A-households
  [
     let x (random -40 - 1)
     let y (random-pycor)

    ;while there are [any?] households on [patch] with coordinates (x,y) or
    ;while the color of coordinates (x,y) is white -> keep looping
    while [ any? households-on patch x y or [pcolor] of patch x y = white ]
    [
       set x (random -40 - 1)
       set y (random-pycor)
    ]

    setxy x y

    set brgy-A? true
    set brgy-B? false
  ]

  create-households brgy-B-households
  [
     let x (random 40 + 1)
     let y (random-pycor)

    ;while there are [any?] households on [patch] with coordinates (x,y) or
    ;while the color of coordinates (x,y) is white -> keep looping
    while [ any? households-on patch x y or [pcolor] of patch x y = white ]
    [
       set x (random 40 + 1)
       set y (random-pycor)
    ]

    setxy x y

    set brgy-B? true
    set brgy-A? false

  ]

  ask households
  [
    set persons-in-household round random-normal 4 1
    set occupied? false
    set pcolor grey
    hide-turtle
  ]
end

to setup-residents

  create-residents brgy-A-households
  [

    set house one-of households with [occupied? = false and brgy-A? = true]
    ask house [ set occupied? true ]
    move-to house

    set preferred-market one-of markets with [brgy-A? = true]

    set susceptible? true
    set exposed? false
    set infected? false
    set recovered? false

    set brgy-A? true
    set brgy-B? false

    set isolated? false
    set moved-today? false

    set susceptibility-rate random-normal brgy-A-mean-susceptibility sd-susceptibility
    set incubation-duration random-normal ave-incubation-period 24

    set hazard-rate random-normal .2985 .0439
    while [ hazard-rate >= 1 ] [ set hazard-rate random-normal .2985 .0439 ]
    set shape "circle"
  ]

  create-residents brgy-B-households
  [

    set house one-of households with [occupied? = false and brgy-B? = true]
    ask house [ set occupied? true ]
    move-to house

    set preferred-market one-of markets with [brgy-B? = true]

    set susceptible? true
    set exposed? false
    set infected? false
    set recovered? false

    set brgy-A? false
    set brgy-B? true

    set isolated? false
    set moved-today? false

    set susceptibility-rate random-normal brgy-B-mean-susceptibility sd-susceptibility
    set incubation-duration random-normal ave-incubation-period 24

    set hazard-rate random-normal .2985 .0439
    while [ hazard-rate >= 1 ] [ set hazard-rate random-normal .2985 .0439 ]

    set shape "triangle"
  ]

  ask min-n-of initial-infected-brgy-A (residents with [brgy-A? = true]) [who]
  [
    set infected? true
    set susceptible? false
    set exposure-duration incubation-duration
    set severe-symptoms-start round random-normal 168 24
  ]

  ask min-n-of initial-infected-brgy-B (residents with [brgy-B? = true]) [who]
  [
    set infected? true
    set susceptible? false
    set exposure-duration incubation-duration
    set severe-symptoms-start round random-normal 168 24
  ]

  ask residents
  [
    set size 1
    set color green
    set-residents-color
  ]


end

to set-residents-color

  ifelse infected? = true
  [ set color red ]
  [ ifelse susceptible? = true
    [ set color green ]
    [ set color yellow ]
  ]

end

to go

  set time ticks mod 24

  set-time-dependent-vars

  ;only infected but not isolated residents can infect
  ask residents with [ infected? =  true ]
  [ infect ]

  ask residents with [ exposed? = true ]
  [ set-exposure ]

  ask residents [ set-residents-color ]

  update-movement

  tick
end

to set-time-dependent-vars

  if time = 0
  [
    set day day + 1
    report-infected-cases
    ask residents with [ moved-today? = true ]
    [ set moved-today? false ]

    ask residents with [ infected? = true]
    [ check-hazard-rate ]

    ask residents with [ infected? = true]
    [ check-isolated ]

  ]

end

;; EPIDEMIOLOGY

to set-exposure

  set exposure-duration exposure-duration + 1

  if exposure-duration >= incubation-duration
  [
    set susceptible? false
    set exposed? false
    set infected? true

    ;report-infected
  ]

end

to infect

  set exposure-duration exposure-duration + 1

  let nearby-uninfected other residents-here with [ infected? = false and exposed? = false ]

  if nearby-uninfected != nobody
  [
    ask nearby-uninfected
    [
      if random-float 1 < susceptibility-rate
      [
        set susceptible? false
        set exposed? true
        set infected? false
        set exposure-duration 0
        set severe-symptoms-start round random-normal 168 24
      ]
    ]
  ]

end


to check-hazard-rate

  ;assumption: only those with severe symptoms
  ;will subject themselves to testing
  if exposure-duration - incubation-duration >= severe-symptoms-start
  [
     ifelse random-float 1 < hazard-rate
     [
      check-deaths
     ]
     [
      check-testing-compliance
     ]
  ]

end

to check-isolated

  foreach isolated-residents
  [

    hazard -> ifelse random-float 1 < random-normal .7425 .0533
    [
      ask house [ set persons-in-household persons-in-household + 1 ]

      ;recover and acquire immunity
      if random-float 1 < .5
      [
        set hazard-rate hazard / 2
        set susceptible? true
        set exposed? false
        set infected? false
        set isolated? false
        set isolated-residents remove hazard isolated-residents
        ;report-recoveries
      ]
    ]
    [
      ;kill resident
      if random-float 1 < hazard
      [
        set isolated-residents remove hazard isolated-residents
        check-deaths
      ]
    ]
  ]

end

to check-testing-compliance

    if random-float 1 < voluntary-testing-compliance
    [
      let number-of-residents 0

      set susceptible? true
      set infected? false
      set exposed? false
      set isolated? true

      ;trick code: get only the hazard-rate value of the isolated, store the value to list,
      ;use the same resident turtle to move but consider it as a new "resident"
      ;create values of the new "resident".
      ;to get the statistics, use a global variable as counter
      ask house
      [
        set persons-in-household persons-in-household - 1
        set number-of-residents persons-in-household
      ]

      set isolated-residents lput hazard-rate isolated-residents
      ;report-isolated

      ifelse number-of-residents <= 0
      [
        hide-turtle
        ;ask house [ set pcolor black]
      ]
      [
        change-mover
      ]
    ]

end

to change-mover

  ;set hazard-rate, susceptibility rate, and incubation duration for the new "resident"

  while[hazard-rate >= 1][set hazard-rate random-normal .2985 .0439]

  ifelse brgy-A? = true
  [ set susceptibility-rate random-normal brgy-A-mean-susceptibility sd-susceptibility ]
  [ set susceptibility-rate random-normal brgy-B-mean-susceptibility sd-susceptibility ]

  set incubation-duration random-normal ave-incubation-period 24

  if random-float 1 < susceptibility-rate
  [
    let infected-on random exposure-duration - incubation-duration
    set exposure-duration infected-on
    set severe-symptoms-start round random-normal 168 24
    ifelse exposure-duration >= incubation-duration
    [
      set susceptible? false
      set infected? true
      set exposed? false
      report-infected
    ]
    [
      set susceptible? false
      set infected? false
      set exposed? true
    ]
  ]

end

to check-deaths

  let number-of-residents 0

  ask house [

    set persons-in-household persons-in-household - 1
    set number-of-residents persons-in-household

    if persons-in-household <= 0
    [
      set pcolor black
    ]
  ]

  ifelse number-of-residents <= 0
  [
    die
  ]
  [
    change-mover
  ]

  ;report-deaths

end

;;MOVEMENTS
to update-movement

  ;; movement

  ifelse fm-pass
  [ set-movement-with-fm-pass ]
  [ set-movement ] ;without fm-pass


  ask residents with [ xcor != [pxcor] of house or ycor != [pycor] of house ]
  [keep-moving]

  ask residents
  [
    if (xcor = [pxcor] of preferred-market) and (ycor = [pycor] of preferred-market) [move-in]
  ]

end

to set-movement-with-fm-pass

  ;if day is not sunday and time is not in curfew
  if (day mod 7) > 0 and (time >= 6 and time < 18)
  [
    ifelse (day mod 7) mod 2 = 1
      [ask residents with [who mod 2 = 1 and (xcor = [pxcor] of house) and (ycor = [pycor] of house) ] [set-move-out-chance]]
      [ask residents with [who mod 2 = 0 and (xcor = [pxcor] of house) and (ycor = [pycor] of house) ] [set-move-out-chance]]
  ]

end

to set-movement
  if (time >= 6 and time < 18)
  [
    ask residents with [(xcor = [pxcor] of house) and (ycor = [pycor] of house) ] [set-move-out-chance]
  ]
end

to set-preferred-market
  ifelse brgy-lockdown = true
  [
    ifelse brgy-A? = true
    [
      ifelse random-float 1 < ( 1 / 9)
        [set preferred-market one-of markets with [ brgy-A? = true ]]
        [
          let choice-holder one-of markets with [ brgy-A? = true]
          set preferred-market one-of [neighbors] of choice-holder
        ]
    ]

    [
      ifelse random-float 1 < ( 1 / 9)
        [set preferred-market one-of markets with [ brgy-B? = true ]]
        [
          let choice-holder one-of markets with [ brgy-B? = true]
          set preferred-market one-of [neighbors] of choice-holder
        ]
    ]
  ]
  ;;if no lockdown
  [
    let choices patches with [pcolor = white]
    ifelse random-float 1 < 0.85
      [
        set preferred-market one-of min-n-of round (count choices / 2) choices [distance myself]
      ]
      [
        set preferred-market one-of max-n-of (count choices - round (count choices / 2)) choices [distance myself]
      ]
  ]

  face preferred-market
  keep-moving
end

to set-move-out-chance

  let ration-system ""

  ifelse brgy-A? = true
    [set ration-system ration-system-brgy-A]
    [set ration-system ration-system-brgy-B]

  if moved-today? = false
  [
    ;;regular and sufficient
    ifelse ration-system = "regular and sufficient rations"
    [
      if random-float 1 < (1 / 720)
      [
        set moved-today? true
        set-preferred-market
      ]
    ]
    [
      ;;regular but insufficient
      ifelse ration-system = "regular but insufficient rations"
      [
        if random-float 1 < (1 / 48)
        [
          set moved-today? true
          set-preferred-market
        ]
      ]
      [
        ;;irregular
        if random-float 1 < (1 / 24)
        [
          set moved-today? true
          set-preferred-market
        ]
      ]
    ]

  ]

end

to keep-moving

  if time >= 17
  [ face patch [pxcor] of house [pycor] of house
    move-to patch [pxcor] of house [pycor] of house ]

  let movement random-normal 4 1
  let distance-ahead distance preferred-market

  ifelse patch-ahead distance-ahead = preferred-market
  [
    face preferred-market
    ifelse (distance-ahead <= 4) or (distance-ahead <= movement)
    [ move-to preferred-market
      set entry-time time
      set market-duration round random-normal 2 .5
    ]
    [ forward movement ]
  ]
  [
    face house
    ;face patch [pxcor] of house [pycor] of house
    ifelse (distancexy [pxcor] of house [pycor] of house <= 4) or (distancexy [pxcor] of house [pycor] of house <= movement )
    [ move-to patch [pxcor] of house [pycor] of house ]
    [ forward movement ]
  ]

end

to move-in

  let exit-time entry-time + market-duration

  if(exit-time + ceiling (distancexy [pxcor] of house [pycor] of house / 4)) > 18
  [set exit-time time]

  if exit-time = time
  [
    face house
    ;face patch [pxcor] of house [pycor] of house
    ifelse (distancexy [pxcor] of house [pycor] of house <= 1 )
    [ move-to patch [pxcor] of house [pycor] of house ]
    [ forward 1]
  ]
end

;; REPORTERS
to report-infected
  ifelse brgy-A? = true
  [ set infected-A infected-A + 1 ]
  [ set infected-B infected-B + 1 ]
end

to report-isolated
  ifelse brgy-A? = true
  [ set isolated-A isolated-A + 1 ]
  [ set isolated-B isolated-B + 1 ]
end

to report-recoveries
  ifelse brgy-A? = true
  [ set recoveries-A recoveries-A + 1 ]
  [ set recoveries-B recoveries-B + 1 ]
end

to report-deaths
  ifelse brgy-A? = true
  [ set deaths-A deaths-A + 1 ]
  [ set deaths-B deaths-B + 1 ]
end

to report-infected-cases
  set infected-cases-A count residents with [brgy-A? =  true and infected? = true]
  set infected-cases-B count residents with [brgy-B? =  true and infected? = true]
  set infected-cases-all count residents with [ infected? = true ]
end
@#$#@#$#@
GRAPHICS-WINDOW
247
14
1319
561
-1
-1
13.14
1
10
1
1
1
0
0
0
1
-40
40
-20
20
0
0
1
ticks
30.0

BUTTON
22
520
92
553
Set up
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
104
521
174
554
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
26
128
223
173
ration-system-brgy-A
ration-system-brgy-A
"regular and sufficient rations" "regular but insufficient rations" "irregular rations"
2

SLIDER
25
257
204
290
brgy-B-households
brgy-B-households
0
250
250.0
5
1
NIL
HORIZONTAL

SLIDER
23
445
205
478
market-count-brgy-A
market-count-brgy-A
0
10
1.0
1
1
NIL
HORIZONTAL

SLIDER
25
295
204
328
initial-infected-brgy-A
initial-infected-brgy-A
0
100
1.0
1
1
NIL
HORIZONTAL

SLIDER
25
332
206
365
initial-infected-brgy-B
initial-infected-brgy-B
0
100
1.0
1
1
NIL
HORIZONTAL

SWITCH
26
48
135
81
fm-pass
fm-pass
0
1
-1000

SLIDER
23
407
183
440
average-r0-brgy-B
average-r0-brgy-B
0.3
6.4
2.1
.1
1
NIL
HORIZONTAL

SWITCH
25
87
158
120
brgy-lockdown
brgy-lockdown
1
1
-1000

SLIDER
22
482
205
515
market-count-brgy-B
market-count-brgy-B
0
10
1.0
1
1
NIL
HORIZONTAL

SLIDER
26
10
235
43
voluntary-testing-compliance
voluntary-testing-compliance
0
1
0.1
.01
1
NIL
HORIZONTAL

SLIDER
24
370
185
403
average-r0-brgy-A
average-r0-brgy-A
0.3
6.4
6.3
.1
1
NIL
HORIZONTAL

CHOOSER
24
172
222
217
ration-system-brgy-B
ration-system-brgy-B
"regular and sufficient rations" "regular but insufficient rations" "irregular rations"
2

MONITOR
18
571
75
616
day
day
17
1
11

SLIDER
25
221
203
254
brgy-A-households
brgy-A-households
0
250
250.0
5
1
NIL
HORIZONTAL

MONITOR
97
570
154
615
time
time
17
1
11

MONITOR
167
571
238
616
population
count residents
17
1
11

PLOT
488
576
835
807
Infected cases per day
Day
Cases
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Brgy-A" 1.0 0 -2674135 true "" "plot infected-cases-A"
"Brgy-B" 1.0 0 -14454117 true "" "plot infected-cases-B"
"All-brgys" 1.0 0 -7500403 true "" "plot infected-cases-all"

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.4
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Deaths Delta" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="8760"/>
    <metric>count dead-brgy-A</metric>
    <metric>count dead-brgy-B</metric>
    <enumeratedValueSet variable="brgy-lockdown">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fm-pass">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ration-system-brgy-A">
      <value value="&quot;irregular rations&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ration-system-brgy-B">
      <value value="&quot;irregular rations&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="brgy-A-households">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="brgy-B-households">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-infected-brgy-A">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-infected-brgy-B">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-r0-brgy-A">
      <value value="5.08"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-r0-brgy-B">
      <value value="5.08"/>
    </enumeratedValueSet>
    <steppedValueSet variable="market-count-brgy-A" first="0" step="1" last="3"/>
    <steppedValueSet variable="market-count-brgy-B" first="0" step="1" last="3"/>
    <enumeratedValueSet variable="voluntary-testing-compliance">
      <value value="0.25"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
