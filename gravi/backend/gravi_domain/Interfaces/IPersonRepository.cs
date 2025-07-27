using gravi_domain.Entities;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace gravi_domain.Interfaces
{
    public interface IPersonRepository
    {
        Task<(string Message, long? Result)> AddPersonAsync(Person newPerson);
        Task<(string Message, bool Result)> UpdatePersonAsync(Person person);
        Task<(string Message, bool Result)> DeletePersonAsync(long? personId);
        Task<Person?> FindPersonByIdAsync(long? personId);
        Task<bool> PersonExistsAsync(long? personId);
    }
}
