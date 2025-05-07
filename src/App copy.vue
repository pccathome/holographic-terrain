<script setup>
import { onMounted, onBeforeUnmount, ref } from 'vue'
import * as THREE from 'three'
import GUI from 'lil-gui'
import { gsap } from 'gsap'
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js'
import { EffectComposer } from 'three/examples/jsm/postprocessing/EffectComposer.js'
import { RenderPass } from 'three/examples/jsm/postprocessing/RenderPass.js'
import { BokehPass } from './Passes/BokehPass.js'

// import { useCanvasTexture } from './composables/useCanvasTexture'

// import LoadingIco from './components/LoadingIco.vue'
import PageWrap from './components/PageWrap.vue'
import Header from './components/Header.vue'
import FooterInfo from './components/FooterInfo.vue'
import terrainVertexShader from './shaders/terrain/vertex.glsl'
import terrainFragmentShader from './shaders/terrain/fragment.glsl'
import terrainDepthVertexShader from './shaders/terrainDepth/vertex.glsl'
import terrainDepthFragmentShader from './shaders/terrainDepth/fragment.glsl'
import vignetteVertexShader from './shaders/overly/vertex.glsl'
import vignetteFragmentShader from './shaders/overly/fragment.glsl'

// Refs & Globals
const webgl = ref(null)
const scene = new THREE.Scene()
const gui = new GUI()

let renderer, effectComposer, bokehPass, renderPass, renderTarget, orbitControls

// Resize
const sizes = {
    width: window.innerWidth,
    height: window.innerHeight,
    pixelRatio: Math.min(window.devicePixelRatio, 2)
}

const setupScene = (canvas) => {
    // Renderer
    renderer = new THREE.WebGLRenderer({ canvas: canvas })
    renderer.setClearColor('#080024', 1)
    renderer.outputEncoding = THREE.sRGBEncoding
    renderer.setSize(sizes.width, sizes.height)
    renderer.setPixelRatio(sizes.pixelRatio)

    // Camera
    const camera = {}
    camera.position = new THREE.Vector3()
    camera.rotation = new THREE.Euler()
    camera.rotation.reorder('YXZ')

    camera.instance = new THREE.PerspectiveCamera(75, sizes.width / sizes.height, 0.1, 100)
    camera.instance.rotation.reorder('YXZ')
    scene.add(camera.instance)

    // orbitControls
    // orbitControls = new OrbitControls(camera.instance, canvas)
    // orbitControls.enableDamping = true
    // orbitControls.addEventListener('change', () => {
    //     renderer.render(scene, camera)
    // })

    // Effect composer
    renderTarget = new THREE.WebGLRenderTarget(800, 600, {
        minFilter: THREE.LinearFilter,
        magFilter: THREE.LinearFilter,
        format: THREE.RGBAFormat,
        encoding: THREE.sRGBEncoding
    })
    effectComposer = new EffectComposer(renderer)
    effectComposer.setSize(sizes.width, sizes.height)
    effectComposer.setPixelRatio(sizes.pixelRatio)

    // Render pass
    renderPass = new RenderPass(scene, camera.instance)
    effectComposer.addPass(renderPass)

    // Bokeh pass
    bokehPass = new BokehPass(scene, camera.instance, {
        focus: 1.0,
        aperture: 0.015,
        maxblur: 0.01,

        width: sizes.width * sizes.pixelRatio,
        height: sizes.height * sizes.pixelRatio
    })

    // bokehPass.enabled = false
    effectComposer.addPass(bokehPass)

    /**
     * Terrain
     */

    const terrain = {
        texture: {
            width: 32,
            height: 128,
            // visible: true,
            canvas: document.createElement('canvas')
        }
    }

    const tex = terrain.texture
    tex.linesCount = 5
    tex.bigLineWidth = 0.08
    tex.smallLineWidth = 0.01
    tex.smallLineAlpha = 0.5
    tex.canvas.width = tex.width
    tex.canvas.height = tex.height
    Object.assign(tex.canvas.style, {
        position: 'fixed',
        top: 0,
        left: 0
    })

    if (tex.visible) {
        document.body.appendChild(tex.canvas)
    }

    tex.context = tex.canvas.getContext('2d')

    tex.instance = new THREE.CanvasTexture(tex.canvas)
    tex.instance.wrapS = THREE.RepeatWrapping
    tex.instance.wrapT = THREE.RepeatWrapping
    tex.instance.magFilter = THREE.NearestFilter

    tex.update = () => {
        tex.context.clearRect(0, 0, tex.width, tex.height)

        // Biggest line
        const actualBigLineWidth = Math.round(tex.height * tex.bigLineWidth)
        tex.context.fillStyle = '#ffffff'
        tex.context.globalAlpha = 1
        tex.context.fillRect(0, 0, tex.width, actualBigLineWidth)

        // Small lines
        const actualSmallLineWidth = Math.round(tex.height * tex.smallLineWidth)
        const smallLinesCount = tex.linesCount - 1

        for (let i = 0; i < smallLinesCount; i++) {
            tex.context.globalAlpha = tex.smallLineAlpha
            tex.context.fillStyle = '#00ffff'
            tex.context.fillRect(
                0,
                actualBigLineWidth + Math.round((tex.height - actualBigLineWidth) / tex.linesCount) * (i + 1),
                tex.width,
                actualSmallLineWidth
            )
        }

        tex.instance.needsUpdate = true
    }

    tex.update()

    // GUI
    gui.add(tex, 'linesCount', 1, 10, 1).onChange((value) => {
        tex.linesCount = value
        tex.update()
        tex.instance.needsUpdate = true
        terrain.material.uniforms.uTexture.value = tex.instance
    })

    gui.add(tex, 'bigLineWidth', 0.0, 0.1, 0.0001).onChange((value) => {
        tex.bigLineWidth = value
        tex.update()
        tex.instance.needsUpdate = true
        terrain.material.uniforms.uTexture.value = tex.instance
    })

    gui.add(tex, 'smallLineWidth', 0.0, 0.05, 0.001).onChange((value) => {
        tex.smallLineWidth = value
        tex.update()
        tex.instance.needsUpdate = true
        terrain.material.uniforms.uTexture.value = tex.instance
    })

    // geometry
    terrain.geometry = new THREE.PlaneGeometry(1, 1, 1000, 1000)
    terrain.geometry.rotateX(-Math.PI * 0.5)

    // terrain uniform
    terrain.uniforms = {
        uTexture: { value: tex.instance },
        uElevation: { value: 2.0 },
        uTextureFrequency: { value: 10.0 },
        uElevationValley: { value: 0.4 },
        uElevationValleyFrequency: { value: 1.5 },
        uElevationGeneral: { value: 0.2 },
        uElevationGeneralFrequency: { value: 0.2 },
        uElevationDetails: { value: 0.2 },
        uElevationDetailsFrequency: { value: 2.012 },
        uTextureOffset: { value: 0.585 },
        uTime: { value: 0.0 },
        uHslHue: { value: 1.0 },
        uHslHueOffset: { value: 0.0 },
        uHslHueFrequency: { value: 10.0 },
        uHslTimeFrequency: { value: 0.05 },
        uHslLightness: { value: 0.75 },
        uHslLightnessVariation: { value: 0.25 },
        uHslLightnessFrequency: { value: 20.0 }
    }

    // Material
    terrain.material = new THREE.ShaderMaterial({
        transparent: true,
        side: THREE.DoubleSide,
        vertexShader: terrainVertexShader,
        fragmentShader: terrainFragmentShader,
        uniforms: terrain.uniforms
    })

    // Depth material
    const uniforms = THREE.UniformsUtils.merge([
        THREE.UniformsLib.common,
        THREE.UniformsLib.displacementmap,
        terrain.uniforms
    ])

    for (const uniformKey in terrain.uniforms) {
        uniforms[uniformKey] = terrain.uniforms[uniformKey]
    }

    terrain.depthMaterial = new THREE.ShaderMaterial({
        uniforms: uniforms,
        vertexShader: terrainDepthVertexShader,
        fragmentShader: terrainDepthFragmentShader
    })

    terrain.depthMaterial.depthPacking = THREE.RGBADepthPacking
    terrain.depthMaterial.blending = THREE.NoBlending

    // Mesh
    terrain.mesh = new THREE.Mesh(terrain.geometry, terrain.material)
    terrain.mesh.scale.set(10, 10, 10)
    terrain.mesh.userData.depthMaterial = terrain.depthMaterial
    scene.add(terrain.mesh)

    gui.add(terrain.material.uniforms.uTextureFrequency, 'value', 0.0, 20).name('uTextureFrequency')
    gui.add(terrain.material.uniforms.uElevation, 'value', 0.0, 5).name('uElevation')

    gui.add(bokehPass.materialBokeh.uniforms.focus, 'value', 0.1, 10).name('bokehPass Focus')
    gui.add(bokehPass.materialBokeh.uniforms.aperture, 'value', 0.0, 0.05).name('bokehPass aperture')
    gui.add(bokehPass.materialBokeh.uniforms.maxblur, 'value', 0.0, 0.05).name('bokehPass maxblur')

    // vignette
    const vignette = {}
    vignette.color = {}
    vignette.color.value = '#4f1f96'
    vignette.color.instance = new THREE.Color(vignette.color.value)
    vignette.geometry = new THREE.PlaneGeometry(2, 2)
    vignette.material = new THREE.ShaderMaterial({
        vertexShader: vignetteVertexShader,
        fragmentShader: vignetteFragmentShader,
        transparent: true,
        depthTest: false,
        uniforms: {
            uOffset: { value: -0.265 },
            uMultiplier: { value: 1.16 },
            uColor: { value: vignette.color.instance }
        }
    })
    vignette.mesh = new THREE.Mesh(vignette.geometry, vignette.material)
    vignette.mesh.userData.noBokeh = true
    vignette.mesh.frostumCulled = false
    scene.add(vignette.mesh)

    const folderV = gui.addFolder('vignette')
    folderV.addColor(vignette.color, 'value').onChange((value) => {
        vignette.color.instance.set(value)
    })

    // gui
    folderV.add(vignette.material.uniforms.uMultiplier, 'value', 0.0, 3).name('Multiplier')
    folderV.add(vignette.material.uniforms.uOffset, 'value', -1, 1).name('Offset')

    /**
     * View
     */

    const view = {}
    view.index = 0
    view.settings = [
        // {
        //     position: { x: 0, y: 2.124, z: -0.172 },
        //     rotation: { x: -1.489, y: -Math.PI, z: 0 },
        //     focus: 2.14,
        //     parallaxMultiplier: 0.25
        // },
        {
            position: { x: 1, y: 0.85, z: 0.1 },
            rotation: { x: -0.833, y: 1.596, z: 1.651 },
            focus: 1.1,
            parallaxMultiplier: 0.12
        }
        // {
        //     position: { x: 1, y: 0.87, z: -0.97 },
        //     rotation: { x: -0.638, y: 2.33, z: 0 },
        //     focus: 1.36,
        //     parallaxMultiplier: 0.12
        // },
        // {
        //     position: { x: -1.43, y: 0.33, z: -0.144 },
        //     rotation: { x: -0.312, y: -1.67, z: 0 },
        //     focus: 1.25,
        //     parallaxMultiplier: 0.12
        // }
    ]

    view.current = view.settings[view.index]

    // Parallax
    view.parallax = {}
    view.parallax.target = {}
    view.parallax.target.x = 0
    view.parallax.target.y = 0
    view.parallax.eased = {}
    view.parallax.eased.x = 0
    view.parallax.eased.y = 0
    view.parallax.eased.multiplier = 4

    window.addEventListener('mousemove', (_event) => {
        view.parallax.target.x = (_event.clientX / sizes.width - 0.5) * view.parallax.multiplier
        view.parallax.target.y = -(_event.clientY / sizes.height - 0.5) * view.parallax.multiplier
    })

    view.change = (_index) => {
        const viewSetting = view.settings[_index]
        camera.position.copy(viewSetting.position)
        camera.rotation.x = viewSetting.rotation.x
        camera.rotation.y = viewSetting.rotation.y

        bokehPass.materialBokeh.uniforms.focus.value = viewSetting.focus
        view.parallax.multiplier = viewSetting.parallaxMultiplier

        view.current = viewSetting
    }
    view.change(0)

    // gui.add(view.change, '_index', { V1: 0, V2: 1, V3: 2, V4: 3 }).onChange((value) => {
    //     view.change(value)
    // })

    // Focus
    const changeFocus = () => {
        gsap.to(bokehPass.materialBokeh.uniforms.focus, {
            duration: 0.5 + Math.random() * 3,
            delay: 0.5 + Math.random() * 1,
            ease: 'power2.inOut',
            onComplete: changeFocus,
            value: view.current.focus + (Math.random() - 0.2)
        })
    }
    changeFocus()

    // resize
    const handleResize = () => {
        // Update sizes
        sizes.width = window.innerWidth
        sizes.height = window.innerHeight
        sizes.pixelRatio = Math.min(window.devicePixelRatio, 2)

        // Update camera
        camera.instance.aspect = sizes.width / sizes.height
        camera.instance.updateProjectionMatrix()

        // Update renderer
        renderer.setSize(sizes.width, sizes.height)
        renderer.setPixelRatio(sizes.pixelRatio)

        // Update effect composer
        effectComposer.setSize(sizes.width, sizes.height)
        effectComposer.setPixelRatio(sizes.pixelRatio)

        // Update passes
        bokehPass.renderTargetDepth.width = sizes.width * sizes.pixelRatio
        bokehPass.renderTargetDepth.height = sizes.height * sizes.pixelRatio
    }

    // Animate
    const clock = new THREE.Clock()
    let lastElapsedTime = 0
    const tick = () => {
        window.addEventListener('resize', handleResize)

        const elapsedTime = clock.getElapsedTime()
        const deltaTime = elapsedTime - lastElapsedTime
        lastElapsedTime = elapsedTime

        // Update uniforms
        terrain.uniforms.uTime.value = elapsedTime

        // Update parallax
        camera.instance.position.copy(camera.position)
        view.parallax.eased.x +=
            (view.parallax.target.x - view.parallax.eased.x) * deltaTime * view.parallax.eased.multiplier
        view.parallax.eased.y +=
            (view.parallax.target.y - view.parallax.eased.y) * deltaTime * view.parallax.eased.multiplier
        camera.instance.translateX(view.parallax.eased.x)
        camera.instance.translateY(view.parallax.eased.y)
        camera.instance.rotation.x = camera.rotation.x
        camera.instance.rotation.y = camera.rotation.y

        // orbitControls.update()

        // renderer.render(scene, camera)
        effectComposer.render()
        window.requestAnimationFrame(tick)
    }

    tick()
}

onMounted(() => {
    if (webgl.value) {
        setupScene(webgl.value)
    }
})
onBeforeUnmount(() => {
    // window.removeEventListener('resize', handleResize)
    renderer?.dispose()
})
</script>

<template>
    <PageWrap>
        <Header />

        <canvas class="outline-none w-full h-dvh" ref="webgl"></canvas>

        <FooterInfo>
            <template v-slot:first>
                <a href="https://www.solarsystemscope.com/" target="_blank" class="underline-offset-2 font-medium"
                    >Earth Textures - Solar system scope</a
                >
            </template>
            <template v-slot:second> </template>
            <template v-slot:github>
                <a href="https://github.com/pccathome/earth" target="_blank" class="underline-offset-2">GitHub</a>
            </template>
        </FooterInfo>
    </PageWrap>
</template>
