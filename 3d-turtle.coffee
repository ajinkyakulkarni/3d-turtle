WIDTH = 640
HEIGHT = 480

FIELD_OF_VIEW = 75
FRUSTUM_NEAR = 0.1
FRUSTUM_FAR = 1000000

CAMERA_DISTANCE = 1000

TURTLE_START_POS = new THREE.Vector3(0, 0, 0)
TURTLE_START_DIR = new THREE.Vector3(0, 1, 0)
TURTLE_START_UP = new THREE.Vector3(0, 0, 1)
TURTLE_START_COLOR = 0xFF0000

DIR_LIGHT_COLOR = 0xFFFFFF
DIR_LIGHT_POS = new THREE.Vector3(1, 1, 1)
DIR_LIGHT_TARGET = new THREE.Vector3(0, 0, 0)
AMB_LIGHT_COLOR = 0x555555

# This controls the level of detail, the roundness, of the cylinders
# dropped by the turtle.
SEGMENTS = 10


deg2rad = (degrees) ->
  degrees / 360 * 2 * Math.PI

# Returns an arbitrary vector perpendicular to vec.
getPerpVec = (vec) ->
  if vec.z == 0
    new THREE.Vector3(0, 0, 1)
  else if vec.y == 0
    new THREE.Vector3(0, 1, 0)
  else
    new THREE.Vector3(0, 1, -(vec.y / vec.z))

# We take the cylinder geometry, which is constantly dropped behind
# by the turtle, and rearrange it a little. We move the pivot,
# the origin of the geometries' vertices, so that it lies
# in the bottom center of the cylinder and we rotate it so that
# Y axis points in the Z axis (this means that now if we orient
# the cylinder using lookAt, the axis of the cylinder will point
# towards the target). PS: The transformations have to be multiplied
# onto the resulting matrix in the opposite order to the one
# in which we want to perform them.
turtleGeometry = new THREE.CylinderGeometry(1, 1, 1, SEGMENTS)
normalizationMatrix = new THREE.Matrix4()
normalizationMatrix.rotateX(Math.PI / 2)
normalizationMatrix.translate(new THREE.Vector3(0, -0.5, 0))
turtleGeometry.applyMatrix(normalizationMatrix)

# Our turtle in space. Maintains its position in space, a unit
# direction vector (where is the turtle pointing now), a unit up
# vector (the direction the turtle's back is pointing), the shading
# material used to paint the current droppings, the width of the
# current droppings, the trail of droppings the turtle has painted
# and whether it is drawing more now. See the constructor for details.
class Turtle3D
  constructor: (@position, @direction, @up, @material, @width = 30) ->
    @direction.normalize()
    @up.normalize()
    @droppings = []
    @drawing = on

  go: (distance) ->
    newPosition = new THREE.Vector3()
    newPosition.add(@position, @direction.clone().multiplyScalar(distance))
    if @drawing
      @droppings.push({ from: @position
                      , to: newPosition
                      , material: @material
                      , width: @width })
    @position = newPosition

  yaw: (angle) ->
    # When we want to change the yaw, we rotate around our 'up' vector.
    # This also means the 'up' vector doesn't change.
    rotation = new THREE.Matrix4().makeRotationAxis @up, deg2rad angle
    rotation.multiplyVector3 @direction
    # Funny JavaScript numbers let our unit vectors grow all the way
    # to NaN if we don't normalize them from time to time. Here, I just
    # normalize them every time I change them.
    @direction.normalize()

  pitch: (angle) ->
    # Changing the pitch means rotating around our 'right' axis. We
    # don't store this one but we can easily compute it using the
    # cross product of 'direction' and 'up'.
    right = new THREE.Vector3().cross(@direction, @up).normalize()
    rotation = new THREE.Matrix4().makeRotationAxis right, deg2rad angle
    rotation.multiplyVector3 @direction
    @direction.normalize()
    rotation.multiplyVector3 @up
    @up.normalize()

  roll: (angle) ->
    # Changing the roll means rotating around our 'direction',
    # therefore 'direction' doesn't have to change at all.
    rotation = new THREE.Matrix4().makeRotationAxis @direction, deg2rad angle
    rotation.multiplyVector3 @up
    @up.normalize()

  penUp: ->
    @drawing = off

  penDown: ->
    @drawing = on

  setWidth: (@width) ->

  setMaterial: (@material) ->

  setColor: (hex) ->
    @setMaterial(new THREE.MeshLambertMaterial({ color: hex
                                               , ambient: hex }))

  # Returns meshes for all the droppings left by the turtle.
  retrieveMeshes: ->
    for {from, to, material, width} in @droppings
      distance = from.distanceTo to

      mesh = new THREE.Mesh(turtleGeometry, material)

      # Calculate the desired dimensions of the trail. Support for
      # different values of bottomRadius and topRadius are from a
      # previous design, it doesn't hurt to have it here so we don't
      # have to research the shearing matrix again if we need it later
      # again.
      bottomRadius = width
      topRadius = width
      height = distance
      shearFactor = (topRadius - bottomRadius) / height

      # I construct the matrix to scale, rotate and position the
      # trail. The transformations are multiplied onto the matrix in
      # the opposite order they are applied, so read from the bottom.
      # Also, order matters. Generally, you want to do scaling first,
      # then rotation and finally translation.
      turtleTransform = new THREE.Matrix4()
      # 4. Finally, we position the whole thing in the correct
      # starting position.
      turtleTransform.translate(from)
      # 3. Rotate the cylinder so that it is pointing from one path
      # node to the next. The third argument is a mandatory 'up'
      # direction. Since we do not care about 'up' when rendering, I
      # just compute some arbitrary vector perpendicular to the
      # direction of sight.
      turtleTransform.lookAt(from, to, getPerpVec(to.clone().subSelf(from)))
      # 2. Use a shearing transformation to make the cylinder have a
      # different radius on the top.
      turtleTransform.multiplySelf(new THREE.Matrix4(1, shearFactor, 0, 0,
                                                     0,           1, 0, 0,
                                                     0, shearFactor, 1, 0,
                                                     0,           0, 0, 1))
      # 1. Scale the cylinder so its radius and height are of the
      # desired magnitude.
      turtleTransform.scale(new THREE.Vector3(bottomRadius, bottomRadius, height))

      mesh.applyMatrix(turtleTransform)
      mesh


window.onload = ->

  codeMirror = CodeMirror.fromTextArea $('#codeMirrorArea').get 0

  try
    renderer = new THREE.WebGLRenderer()
  catch e
    console.log "loading WebGLRenderer failed, trying CanvasRenderer"
    renderer = new THREE.CanvasRenderer()

  renderer.setSize WIDTH, HEIGHT
  document.body.appendChild renderer.domElement

  camera = new THREE.PerspectiveCamera(FIELD_OF_VIEW,
                                       WIDTH / HEIGHT,
                                       FRUSTUM_NEAR,
                                       FRUSTUM_FAR)
  camera.position.set(0, 0, CAMERA_DISTANCE)
  # This doesn't matter, as after something is rendered, the camera is
  # controlled by the OrbitControls, whose 'center' we set to the
  # centroid of the rendered stuff.
  camera.lookAt(new THREE.Vector3(0, 0, 0))

  controls = new THREE.OrbitControls(camera, renderer.domElement)

  scene = new THREE.Scene()

  animate = ->
    # This causes the browser to call our animate repeatedly in some
    # way which is suitable for graphics rendering.
    requestAnimationFrame animate
    controls.update()
    renderer.render scene, camera

  animate()

  $('#runButton').click ->

    material = new THREE.MeshLambertMaterial({ color: TURTLE_START_COLOR
                                             , ambient: TURTLE_START_COLOR })
    
    myTurtle = new Turtle3D(TURTLE_START_POS,
                            TURTLE_START_DIR,
                            TURTLE_START_UP,
                            material)

    # Since my Turtle3D is a nice object with its own fields and I
    # want to use its methods as global function in a global context,
    # I export them like this.
    window.go = -> myTurtle.go.apply myTurtle, arguments
    window.yaw = -> myTurtle.yaw.apply myTurtle, arguments
    window.pitch = -> myTurtle.pitch.apply myTurtle, arguments
    window.roll = -> myTurtle.roll.apply myTurtle, arguments
    window.penUp = -> myTurtle.penUp.apply myTurtle, arguments
    window.penDown = -> myTurtle.penDown.apply myTurtle, arguments
    window.color = -> myTurtle.setColor.apply myTurtle, arguments
    window.width = -> myTurtle.setWidth.apply myTurtle, arguments

    eval codeMirror.getValue()

    # We dump the old scene and populate a new one.
    scene = new THREE.Scene()

    meshes = myTurtle.retrieveMeshes()
    for mesh in meshes
      scene.add(mesh)

    centroid = new THREE.Vector3()
    for mesh in meshes
      centroid.addSelf(mesh.position)
    centroid.divideScalar(meshes.length)

    # We center the camera around the centroid of the generated geometry.
    camera.position = new THREE.Vector3(0, 0, CAMERA_DISTANCE).addSelf(centroid)
    controls.center = centroid

    dirLight = new THREE.DirectionalLight(DIR_LIGHT_COLOR)
    dirLight.position = DIR_LIGHT_POS
    dirLight.target.position = DIR_LIGHT_TARGET
    scene.add(dirLight)

    ambLight = new THREE.AmbientLight(AMB_LIGHT_COLOR)
    scene.add(ambLight)

    $('#numMeshes').html "#{meshes.length} meshes in the scene"
