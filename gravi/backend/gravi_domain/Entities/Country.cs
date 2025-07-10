using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace gravi_domain.Entities
{
    public class Country
    {
        public required int CountryId { get; init; }
        public required string CountryName { get; init; }
    }
}
