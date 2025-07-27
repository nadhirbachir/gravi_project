using AutoMapper;
using Google.Protobuf.Compiler;
using gravi_application.DTOs;
using gravi_application.Interfaces;
using gravi_domain.Entities;
using gravi_infrastructure.Data.UnitOfWork;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace gravi_application.Services
{
    public class UserPersonFactoryService : IUserPersonFactoryService
    {
        private readonly IUnitOfWorkAsync _unitOfWork;
        private readonly IMapper _mapper;

        public UserPersonFactoryService(IUnitOfWorkAsync unitOfWork, IMapper mapper)
        {
            _unitOfWork = unitOfWork ?? throw new ArgumentNullException(nameof(unitOfWork));
            _mapper = mapper ?? throw new ArgumentNullException(nameof(mapper));
        }

        private async Task<(string Message, long? NewPersonId)> CreatePersonAsync(Person person)
        {
            if (person == null)
                return ("Person cannot be null.", null);

            try
            {
                var result = await _unitOfWork.Registry.Person.AddPersonAsync(person);
                return result;
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Failed to create person.", ex);
            }
        }

        private async Task<(string Message, Person? NewPerson)> CreatePersonByPersonDTOAsync(AddPersonDTO personDTO)
        {
            if (personDTO == null)
                return ("Person data cannot be null.", null);

            if (string.IsNullOrWhiteSpace(personDTO.FirstName) || string.IsNullOrWhiteSpace(personDTO.LastName))
                return ("First name and last name are required.", null);

            Person newPerson = _mapper.Map<Person>(personDTO);


            try
            {
                var createResult = await CreatePersonAsync(newPerson);
                if (createResult.NewPersonId == null)
                    return (createResult.Message, null);

                var newPersonCreatedModel = await _unitOfWork.Registry.Person.FindPersonByIdAsync(createResult.NewPersonId);
                if (newPersonCreatedModel == null)
                    return ("Person creation failed - could not retrieve created person.", null);

                return ("Person created successfully.", newPersonCreatedModel);
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Failed to create person from DTO.", ex);
            }
        }


        private async Task<(string Message, long? NewUserId)> CreateUserAsync(User user)
        {
            if (user?.Person == null)
                return ("User and person information are required.", null);

            var anotherUserExists = await _unitOfWork.Registry.User.UserExistsByPersonIdAsync(user.Person.PersonId);
            if (anotherUserExists)
                return ("Cannot create user - another user already exists with this person information.", null);

            try
            {
                var result = await _unitOfWork.Registry.User.AddUserAsync(user);
                return result;
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Failed to create user.", ex);
            }
        }

        private async Task<(string Message, User? NewUser)> CreateUserByUserDTOAsync(AddUserDTO userDTO, Person? person)
        {
            if (person?.PersonId == null)
                return ("Valid person information is required to create user.", null);

            if (userDTO == null)
                return ("User data cannot be null.", null);

            var user = _mapper.Map<User>(userDTO);
            user.Person = person;

            try
            {
                var createResult = await CreateUserAsync(user);
                if (createResult.NewUserId == null)
                    return (createResult.Message, null);

                User? newUser = await _unitOfWork.Registry.User.FindUserByIdAsync(createResult.NewUserId);
                if (newUser == null)
                    return ("User creation failed - could not retrieve created user.", null);

                return ("User created successfully.", newUser);
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Failed to create user from DTO.", ex);
            }
        }


        public async Task<(string Message, UserDTO? NewUser)> CreateUserWithPersonAsync(AddUserDTO userDTO)
        {
            await _unitOfWork.BeginTransactionAsync();

            try
            {
                var personCreationResult = await CreatePersonByPersonDTOAsync(userDTO.Person);
                if (personCreationResult.NewPerson == null)
                {
                    await _unitOfWork.RollBackAsync();
                    return (personCreationResult.Message, null);
                }

                var newUser = await CreateUserByUserDTOAsync(userDTO, personCreationResult.NewPerson);
                if (newUser.NewUser == null)
                {
                    await _unitOfWork.RollBackAsync();
                    return (newUser.Message, null);
                }

                await _unitOfWork.CommitAsync();

                var newUserDTO = _mapper.Map<UserDTO>(newUser.NewUser);
                return (newUser.Message, newUserDTO);
            }
            catch (Exception ex)
            {
                await _unitOfWork.RollBackAsync();
                throw new InvalidOperationException("Failed to create user with person.", ex);
            }
        }

    }
}

