using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace gravi_application.DTOs
{
    public class CountryDTO
    {
        public required int CountryId { get; init; }
        public required string CountryName { get; init; }
    }
}
