using AutoMapper;
using gravi_application.DTOs;
using gravi_application.Interfaces;
using gravi_infrastructure.Data.UnitOfWork;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace gravi_application.Services
{
    public class CountryService : ICountryService
    {
        private readonly IUnitOfWorkAsync _unitOfWork;
        private readonly IMapper _mapper;

        public CountryService(IUnitOfWorkAsync unitOfWork, IMapper mapper)
        {
            _unitOfWork = unitOfWork;
            _mapper = mapper;
        }

        public async Task<CountryDTO?> FindCountryByIdAsync(int id)
        {
            var country = await _unitOfWork.Registry.Country.FindByIdAsync(id);
            return country == null? null : _mapper.Map<CountryDTO?>(country);
        }

        public async Task<CountryDTO?> FindCountryByNameAsync(string name)
        {
            var country = await _unitOfWork.Registry.Country.FindByNameAsync(name);
            return country == null? null : _mapper.Map<CountryDTO?>(country);
        }

        public async Task<IEnumerable<CountryDTO>> GetAllCountriesAsync()
        {
            var countries = await _unitOfWork.Registry.Country.GetAllCountriesAsync();
            return _mapper.Map<IEnumerable<CountryDTO>>(countries);
        }


    }
}
