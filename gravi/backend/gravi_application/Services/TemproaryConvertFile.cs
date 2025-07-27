using gravi_application.DTOs;
using gravi_domain.Entities;
using gravi_infrastructure.Data.UnitOfWork;
using Microsoft.AspNetCore.Identity;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace gravi_application.Services
{
    public class TemproaryConvertFile
    {
        /*
        public long? PersonId { get; init; }

        public required string FirstName { get; set; }

        public string? MiddleName { get; set; }

        public required string LastName { get; set; }

        public required Country Country { get; set; }

        public required DateTime DateOfBirth { get; set; }

        public required GenderType Gender { get; set; }
         */

        private readonly PasswordHasher<User> _hasher;
        private readonly IUnitOfWorkAsync _unitOfWork;

        public TemproaryConvertFile(IUnitOfWorkAsync uow, PasswordHasher<User> hasher) 
        { 
            _hasher = hasher;
            _unitOfWork = uow;
        }

        public User GetUserFromAddDTO(AddUserDTO dto)
        {
            if (dto == null) return null;

            return new User
            { 
                UserId = null,
                Person = null,
                Username = dto.Username,
                PhoneNumber = dto.PhoneNumber,
                Email = dto.Email,
                IsEmailVerified = false,
                PasswordHash = _hasher.HashPassword(null, dto.Password),
            }
            ;
        }

        public Person GetPersonFromAddDTO(AddPersonDTO dto)
        {
            if (dto == null) return null;

            return new Person
            {
                PersonId = null,
                FirstName = dto.FirstName,
                MiddleName = dto.MiddleName,
                LastName = dto.LastName,
                Country = _unitOfWork.Registry.Country.FindByName(dto.CountryName) ?? throw new Exception("country doesn't exist."),
                DateOfBirth = dto.DateOfBirth,
                Gender = dto.Gender
            }
            ;
        }
    }
}
