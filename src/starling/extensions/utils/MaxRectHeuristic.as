// =================================================================================================
//
//	Starling Framework
//	Copyright Gamua GmbH. All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package starling.extensions.utils
{
    import starling.errors.AbstractClassError;

    /**
     * Specifies the different heuristic rules that can be used when deciding where to place a new rectangle.
     *
     * @see starling.extensions.utils.MaxRectPacker
     */
    public class MaxRectHeuristic
    {
        /** @private */
        public function MaxRectHeuristic() { throw new AbstractClassError(); }

        /** Positions the rectangle against the short side of a free rectangle into which it fits the best. */
        public static const BEST_SHORT_SIDE_FIT:String = "bestShortSideFit";

        /** Positions the rectangle against the long side of a free rectangle into which it fits the best. */
        public static const BEST_LONG_SIDE_FIT:String = "bestLongSideFit";

        /** Positions the rectangle into the smallest free rectangle into which it fits. */
        public static const BEST_AREA_FIT:String = "bestAreaFit";

        /** Does Tetris like placement. */
        public static const RULE_BOTTOM_LEFT:String = "bottomLeftRule";

        /** Chooses the placement where the rectangle touches other rectangles as much as possible. */
        public static const RULE_CONTACT_POINT:String = "contactPointRule";
    }
}
