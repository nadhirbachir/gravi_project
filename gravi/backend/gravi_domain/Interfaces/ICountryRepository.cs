using gravi_domain.Entities;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace gravi_domain.Interfaces
{
    public interface ICountryRepository
    {
        Task<Country?> FindByNameAsync(string name);
        Task<Country?> FindByIdAsync(int id);
        Task<IEnumerable<Country?>> GetAllCountriesAsync();
    }
}
