using gravi_application.DTOs;
using gravi_application.Interfaces;
using Microsoft.AspNetCore.Mvc;

namespace gravi_presentation.Controllers
{
    [ApiController]
    [Route("testapi/[Controller]")]
    public class TestController : ControllerBase
    {
        private readonly ICountryService _countryService; // Assuming ICountryService is the interface

        // Inject the service via constructor
        public TestController(ICountryService countryService)
        {
            _countryService = countryService;
        }

        [HttpGet("GetCountryById/{id}")]
        public async Task<ActionResult<CountryDTO>> GetCountryById(int id)
        {
            var country = await _countryService.FindCountryByIdAsync(id);
            if (country == null)
            {
                return NotFound();  // Return 404 if country is not found
            }

            return Ok(country); // Return the country if found
        }

        [HttpGet("GetCountryByName/{name}")]
        public async Task<ActionResult<CountryDTO>> GetCountryByName(string name)
        {
            var country = await _countryService.FindCountryByNameAsync(name);
            if (country == null)
            {
                return NotFound();
            }
            return Ok(country);
        }

        [HttpGet("GetCountries")]
        public async Task<ActionResult<IEnumerable<CountryDTO>>> GetCountries()
        {
            var countries = await _countryService.GetAllCountriesAsync();
            if (countries == null)
            {
                return NotFound();
            }
            return Ok(countries);
        }
    }
}
