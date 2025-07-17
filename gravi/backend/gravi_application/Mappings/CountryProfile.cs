using AutoMapper;
using gravi_application.DTOs;
using gravi_domain.Entities;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace gravi_application.Mappings
{
    public class CountryProfile : Profile
    {
        public CountryProfile() 
        {
            CreateMap<Country, CountryDTO>();
            CreateMap<CountryDTO, Country>();
        }
    }
}
