# me - this DAT
#
# frame - the current frame
# state - True if the timeline is paused
#
# Make sure the corresponding toggle is enabled in the Execute DAT.


def onStart():
    return


def onCreate():
    return


def onExit():
    return


def onFrameStart(frame):
    return


def onFrameEnd(frame):
    p = parent().par

    geo = p.Geometry
    render = p.Render
    cam = p.Camera

    width = op(render).width
    height = op(render).height

    model = op(geo).worldTransform
    view = (op(cam).worldTransform).getInverse()
    proj = op(cam).projection(width, height)

    mvp = proj * view * model

    t = op("prevMVP")
    for i in range(4):
        for j in range(4):
            t[i, j] = mvp[i, j]
    return


def onPlayStateChange(state):
    return


def onDeviceChange():
    return


def onProjectPreSave():
    return


def onProjectPostSave():
    return
