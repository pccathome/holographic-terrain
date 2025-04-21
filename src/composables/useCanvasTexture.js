import * as THREE from 'three'

export function useCanvasTexture(options = {}) {
    const {
        width = 64,
        height = 64,
        visible = false,
        draw = null // callback(canvas, context)
    } = options

    const canvas = document.createElement('canvas')
    canvas.width = width
    canvas.height = height

    Object.assign(canvas.style, {
        position: 'fixed',
        top: 0,
        left: 0,
        zIndex: 10,
        display: visible ? 'block' : 'none'
    })

    if (visible) document.body.appendChild(canvas)

    const context = canvas.getContext('2d')

    const texture = new THREE.CanvasTexture(canvas)
    texture.wrapS = THREE.RepeatWrapping
    texture.wrapT = THREE.RepeatWrapping
    texture.magFilter = THREE.NearestFilter

    const update = () => {
        if (draw && typeof draw === 'function') {
            draw(canvas, context)
        } else {
            // 預設填滿灰色背景
            context.fillStyle = 'white'
            context.fillRect(0, 0, canvas.width, canvas.height)
        }
        texture.needsUpdate = true
    }

    update()

    return {
        canvas,
        context,
        texture,
        update
    }
}
