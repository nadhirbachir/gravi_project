using AutoMapper;
using gravi_application.DTOs;
using gravi_domain.Entities;
using gravi_domain.Interfaces;
using gravi_infrastructure.Data.UnitOfWork;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace gravi_application.Mappings.Resolvers
{
    public class CountryResolver : IValueResolver<AddPersonDTO, Person, Country>
    {
        private readonly IUnitOfWorkAsync _unitOfWorkAsync;

        public CountryResolver(IUnitOfWorkAsync unitOfWorkAsync)
        {
            _unitOfWorkAsync = unitOfWorkAsync;
        }

        public Country Resolve(AddPersonDTO src, Person dst, Country dstCountry, ResolutionContext context)
        {
            // This would block the asynchronous call to make it synchronous.
            // However, blocking async code is not ideal, and it can lead to performance issues or deadlocks.
            var country = _unitOfWorkAsync.Registry.Country.FindByName(src.CountryName);

            if (country == null)
                throw new KeyNotFoundException($"country named {src.CountryName} NOT found.");

            return country;
        }

    }
}
