// =================================================================================================
//
//	Starling Framework
//	Copyright Gamua GmbH. All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package
{
    import flash.display.Sprite;
    import flash.system.Capabilities;

    import starling.core.Starling;

    [SWF(width="800", height="600", frameRate="60", backgroundColor="#202020")]
    public class Startup extends Sprite
    {
        private var _starling:Starling;

        public function Startup()
        {
            _starling = new Starling(Demo, stage);
            _starling.enableErrorChecking = Capabilities.isDebugger;
            _starling.skipUnchangedFrames = true;
            _starling.showStats = true;
            _starling.start();
        }
    }
}
