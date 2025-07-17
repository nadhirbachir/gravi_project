using gravi_application.DTOs;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace gravi_application.Interfaces
{
    public interface ICountryService
    {
        Task<CountryDTO?> FindCountryByIdAsync(int countryId);
        Task<CountryDTO?> FindCountryByNameAsync(string name);
        Task<IEnumerable<CountryDTO>> GetAllCountriesAsync();
    }
}
