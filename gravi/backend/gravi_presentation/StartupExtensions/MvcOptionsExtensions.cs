using Microsoft.AspNetCore.Mvc;

namespace gravi_presentation.StartupExtensions
{
    public static class MvcOptionsExtensions
    {
        public static MvcOptions AddFilters(this MvcOptions options)
        {
            // add filters here...


            return options;
        }
    }
}
