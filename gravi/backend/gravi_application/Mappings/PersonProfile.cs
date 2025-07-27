using AutoMapper;
using gravi_application.DTOs;
using gravi_application.Mappings.Resolvers;
using gravi_domain.Entities;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace gravi_application.Mappings
{
    public class PersonProfile : Profile
    {

        /*
         public class AddPersonDTO
        {

            public required string FirstName { get; set; }
            public string? MiddleName { get; set; }
            public required string LastName { get; set; }

            public required string CountryName { get; set; }
            public required DateTime DateOfBirth { get; set; }
            public required GenderType Gender { get; set; }
        }
         
        public class Person
        {
            public long? PersonId { get; init; }            ignore

            public required string FirstName { get; set; }
            public string? MiddleName { get; set; }
            public required string LastName { get; set; }

            public required Country Country { get; set; }
            public required DateTime DateOfBirth { get; set; }
            public required GenderType Gender { get; set; }
        }

        public class PersonDTO
        {
            public long? PersonId { get; init; }
        
            public required string FirstName { get; set; }
            public string? MiddleName { get; set; } = string.Empty;
            public required string LastName { get; set; }

            public required CountryDTO Country { get; set; }
            public required DateTime DateOfBirth { get; set; }
            public required GenderType Gender { get; set; }
        }
         
         */

        public PersonProfile()
        {
            CreateMap<AddPersonDTO, Person>()
                .ForMember(dest => dest.Country, opt => opt.MapFrom<CountryResolver>())
                .ForMember(dest => dest.PersonId, opt => opt.Ignore())
                ;

            CreateMap<Person, PersonDTO>()
                ;




            
        }
    }
}
