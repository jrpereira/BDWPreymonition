-- Proposed MCT player.notifications objects; replace with MCT's file once it ships.
return {
    name = "player.notifications",
    objects = {
        hud = { source = 'lookup', required = true,
            class = '/Game/_Dawnwalker/UI/_Unified/HUD/WBP_GameHUD.WBP_GameHUD_C' },
        hud_root = { source = 'reference', from = 'hud', member = 'WidgetTree.RootWidget',
            required = true },
        cue = { source = 'create', class = '/Script/UMG.Overlay',
            outer = 'hud_root', parent = 'hud_root', layout = 'fill' },
    },
}
